package idempotency

import (
	"context"
	"errors"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	ErrAlreadyProcessed  = errors.New("event has already been processed")
	ErrConcurrentProcess = errors.New("event is currently being processed by another worker")
)

const (
	StatusPending   = "pending"
	StatusCompleted = "completed"
	StatusFailed    = "failed"
)

// EventState represents the deduplication record stored in Firestore or memory.
type EventState struct {
	EventID     string    `firestore:"event_id" json:"event_id"`
	HandlerName string    `firestore:"handler_name" json:"handler_name"`
	Status      string    `firestore:"status" json:"status"`
	ProcessedAt time.Time `firestore:"processed_at" json:"processed_at"`
	Error       string    `firestore:"error,omitempty" json:"error,omitempty"`
	Attempt     int       `firestore:"attempt" json:"attempt"`
}

// Guard defines the interface for event deduplication.
type Guard interface {
	LockOrSkip(ctx context.Context, handlerName, eventID string) (alreadyProcessed bool, err error)
	MarkCompleted(ctx context.Context, handlerName, eventID string) error
	MarkFailed(ctx context.Context, handlerName, eventID string, execErr error) error
	Execute(ctx context.Context, handlerName, eventID string, fn func(ctx context.Context) error) error
}

// ExecuteGuard executes a function idempotently using Guard.
func ExecuteGuard(ctx context.Context, g Guard, handlerName, eventID string, fn func(ctx context.Context) error) error {
	alreadyProcessed, err := g.LockOrSkip(ctx, handlerName, eventID)
	if err != nil {
		return err
	}
	if alreadyProcessed {
		return nil
	}

	execErr := fn(ctx)
	if execErr != nil {
		if markErr := g.MarkFailed(ctx, handlerName, eventID, execErr); markErr != nil {
			return fmt.Errorf("execution failed: %v (failed to mark state failed: %v)", execErr, markErr)
		}
		return execErr
	}

	return g.MarkCompleted(ctx, handlerName, eventID)
}

// FirestoreGuard implements Guard using GCP Firestore transactions.
type FirestoreGuard struct {
	client         *firestore.Client
	collectionName string
	lockTTL        time.Duration
}

// NewFirestoreGuard creates a new FirestoreGuard.
func NewFirestoreGuard(client *firestore.Client, collectionName string) *FirestoreGuard {
	if collectionName == "" {
		collectionName = "go_worker_state"
	}
	return &FirestoreGuard{
		client:         client,
		collectionName: collectionName,
		lockTTL:        5 * time.Minute,
	}
}

func (g *FirestoreGuard) docRef(handlerName, eventID string) *firestore.DocumentRef {
	docID := fmt.Sprintf("%s_%s", handlerName, eventID)
	return g.client.Collection(g.collectionName).Doc(docID)
}

func (g *FirestoreGuard) LockOrSkip(ctx context.Context, handlerName, eventID string) (bool, error) {
	docRef := g.docRef(handlerName, eventID)
	var alreadyProcessed bool

	err := g.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		docSnap, err := tx.Get(docRef)
		if err != nil && status.Code(err) != codes.NotFound {
			return err
		}

		now := time.Now().UTC()

		if docSnap.Exists() {
			var state EventState
			if err := docSnap.DataTo(&state); err != nil {
				return fmt.Errorf("failed to parse event state: %w", err)
			}

			if state.Status == StatusCompleted {
				alreadyProcessed = true
				return nil
			}

			if state.Status == StatusPending {
				if now.Sub(state.ProcessedAt) < g.lockTTL {
					alreadyProcessed = true
					return nil
				}
				state.Attempt++
			} else if state.Status == StatusFailed {
				state.Attempt++
			} else {
				state.Attempt++
			}

			newState := EventState{
				EventID:     eventID,
				HandlerName: handlerName,
				Status:      StatusPending,
				ProcessedAt: now,
				Attempt:     state.Attempt,
			}
			alreadyProcessed = false
			return tx.Set(docRef, newState)
		}

		newState := EventState{
			EventID:     eventID,
			HandlerName: handlerName,
			Status:      StatusPending,
			ProcessedAt: now,
			Attempt:     1,
		}
		alreadyProcessed = false
		return tx.Set(docRef, newState)
	})

	if err != nil {
		return false, fmt.Errorf("idempotency LockOrSkip transaction error: %w", err)
	}

	return alreadyProcessed, nil
}

func (g *FirestoreGuard) MarkCompleted(ctx context.Context, handlerName, eventID string) error {
	docRef := g.docRef(handlerName, eventID)
	now := time.Now().UTC()
	_, err := docRef.Update(ctx, []firestore.Update{
		{Path: "status", Value: StatusCompleted},
		{Path: "processed_at", Value: now},
		{Path: "error", Value: ""},
	})
	if err != nil {
		return fmt.Errorf("failed to mark event completed: %w", err)
	}
	return nil
}

func (g *FirestoreGuard) MarkFailed(ctx context.Context, handlerName, eventID string, execErr error) error {
	docRef := g.docRef(handlerName, eventID)
	now := time.Now().UTC()
	errMsg := ""
	if execErr != nil {
		errMsg = execErr.Error()
	}
	_, err := docRef.Update(ctx, []firestore.Update{
		{Path: "status", Value: StatusFailed},
		{Path: "processed_at", Value: now},
		{Path: "error", Value: errMsg},
	})
	if err != nil {
		return fmt.Errorf("failed to mark event failed: %w", err)
	}
	return nil
}

func (g *FirestoreGuard) Execute(ctx context.Context, handlerName, eventID string, fn func(ctx context.Context) error) error {
	return ExecuteGuard(ctx, g, handlerName, eventID, fn)
}
