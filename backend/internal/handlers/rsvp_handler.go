package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

// RSVPRepository defines the interface for atomic RSVP counter updates on event documents.
type RSVPRepository interface {
	UpdateEventCounters(ctx context.Context, eventID string, deltaGoing, deltaInterested, deltaNotGoing int64) error
}

// FirestoreRSVPRepository implements RSVPRepository using Cloud Firestore transactions.
type FirestoreRSVPRepository struct {
	client *firestore.Client
}

// NewFirestoreRSVPRepository creates a new FirestoreRSVPRepository instance.
func NewFirestoreRSVPRepository(client *firestore.Client) *FirestoreRSVPRepository {
	return &FirestoreRSVPRepository{client: client}
}

// UpdateEventCounters updates event counter fields atomically within a Firestore transaction.
func (r *FirestoreRSVPRepository) UpdateEventCounters(ctx context.Context, eventID string, deltaGoing, deltaInterested, deltaNotGoing int64) error {
	if r.client == nil {
		return errors.New("firestore client is nil")
	}

	eventRef := r.client.Collection("events").Doc(eventID)

	return r.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		docSnap, err := tx.Get(eventRef)
		if err != nil {
			if status.Code(err) == codes.NotFound {
				return fmt.Errorf("event document not found: %s", eventID)
			}
			return fmt.Errorf("failed to read event document %s: %w", eventID, err)
		}

		var currentGoing int64
		var currentInterested int64
		var currentNotGoing int64

		if val, err := docSnap.DataAt("current_participants"); err == nil {
			currentGoing = toInt64Value(val)
		}
		if val, err := docSnap.DataAt("interested_count"); err == nil {
			currentInterested = toInt64Value(val)
		}
		if val, err := docSnap.DataAt("not_going_count"); err == nil {
			currentNotGoing = toInt64Value(val)
		}

		newGoing := maxZero(currentGoing + deltaGoing)
		newInterested := maxZero(currentInterested + deltaInterested)
		newNotGoing := maxZero(currentNotGoing + deltaNotGoing)

		updates := []firestore.Update{
			{Path: "current_participants", Value: newGoing},
			{Path: "interested_count", Value: newInterested},
			{Path: "not_going_count", Value: newNotGoing},
			{Path: "updated_at", Value: time.Now().UTC()},
		}

		return tx.Update(eventRef, updates)
	})
}

func toInt64Value(v interface{}) int64 {
	switch val := v.(type) {
	case int64:
		return val
	case int:
		return int64(val)
	case float64:
		return int64(val)
	case string:
		var parsed int64
		_, err := fmt.Sscanf(val, "%d", &parsed)
		if err == nil {
			return parsed
		}
	}
	return 0
}

func maxZero(val int64) int64 {
	if val < 0 {
		return 0
	}
	return val
}

// RSVPHandler processes RSVP CloudEvents to aggregate event participation counters.
type RSVPHandler struct {
	guard  idempotency.Guard
	repo   RSVPRepository
	logger *log.Logger
}

// NewRSVPHandler constructs a new RSVPHandler.
func NewRSVPHandler(guard idempotency.Guard, repo RSVPRepository) *RSVPHandler {
	return &RSVPHandler{
		guard:  guard,
		repo:   repo,
		logger: log.New(os.Stdout, "[RSVP_HANDLER] ", log.LstdFlags|log.LUTC),
	}
}

type parsedCloudEvent struct {
	ID      string
	Subject string
	Data    models.DocumentEventData
}

func parseCloudEvent(r *http.Request) (*parsedCloudEvent, error) {
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read request body: %w", err)
	}
	if len(bodyBytes) == 0 {
		return nil, errors.New("request body is empty")
	}

	res := &parsedCloudEvent{}

	var structCE models.CloudEvent[models.DocumentEventData]
	if err := json.Unmarshal(bodyBytes, &structCE); err == nil && structCE.ID != "" {
		res.ID = structCE.ID
		res.Subject = structCE.Subject
		res.Data = structCE.Data
	} else {
		var docData models.DocumentEventData
		if err := json.Unmarshal(bodyBytes, &docData); err != nil {
			return nil, fmt.Errorf("failed to parse event payload JSON: %w", err)
		}
		res.Data = docData
	}

	if res.ID == "" {
		res.ID = r.Header.Get("ce-id")
		if res.ID == "" {
			res.ID = r.Header.Get("CloudEvent-ID")
		}
	}

	if res.Subject == "" {
		res.Subject = r.Header.Get("ce-subject")
		if res.Subject == "" {
			res.Subject = r.Header.Get("CloudEvent-Subject")
		}
	}

	if res.ID == "" {
		return nil, errors.New("missing CloudEvent ID in body or headers")
	}

	return res, nil
}

// ExtractRSVPPathParams extracts eventId and userId from document resource path or ce-subject.
func ExtractRSVPPathParams(resourceName string) (string, string, error) {
	if resourceName == "" {
		return "", "", errors.New("empty resource path")
	}

	normalized := strings.TrimPrefix(resourceName, "/")
	parts := strings.Split(normalized, "/")

	for i := 0; i < len(parts)-3; i++ {
		if parts[i] == "events" && parts[i+2] == "rsvps" {
			eventID := parts[i+1]
			userID := parts[i+3]
			if eventID != "" && userID != "" {
				return eventID, userID, nil
			}
		}
	}

	return "", "", fmt.Errorf("invalid RSVP document path format: %s", resourceName)
}

func statusToVector(status string) (going, interested, notGoing int64) {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "going":
		return 1, 0, 0
	case "interested":
		return 0, 1, 0
	case "not_going":
		return 0, 0, 1
	default:
		return 0, 0, 0
	}
}

// ComputeRSVPStatusDelta calculates status transition deltas between old and new RSVP states.
func ComputeRSVPStatusDelta(oldStatus, newStatus string) (deltaGoing, deltaInterested, deltaNotGoing int64) {
	oldG, oldI, oldN := statusToVector(oldStatus)
	newG, newI, newN := statusToVector(newStatus)

	return newG - oldG, newI - oldI, newN - oldN
}

// ServeHTTP handles HTTP POST requests containing CloudEvents for RSVP document mutations.
func (h *RSVPHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	parsed, err := parseCloudEvent(r)
	if err != nil {
		h.logger.Printf("[ERROR] Invalid CloudEvent payload: %v", err)
		http.Error(w, fmt.Sprintf("invalid CloudEvent: %v", err), http.StatusBadRequest)
		return
	}

	alreadyProcessed, err := h.guard.LockOrSkip(r.Context(), "rsvp_handler", parsed.ID)
	if err != nil {
		h.logger.Printf("[ERROR] Idempotency lock error for event %s: %v", parsed.ID, err)
		http.Error(w, fmt.Sprintf("idempotency error: %v", err), http.StatusInternalServerError)
		return
	}
	if alreadyProcessed {
		h.logger.Printf("[INFO] Skipping already processed event %s", parsed.ID)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"skipped","reason":"duplicate_event"}`))
		return
	}

	eventID, _, pathErr := ExtractRSVPPathParams(parsed.Subject)
	if pathErr != nil {
		eventID, _, pathErr = ExtractRSVPPathParams(parsed.Data.Value.Name)
		if pathErr != nil {
			eventID, _, pathErr = ExtractRSVPPathParams(parsed.Data.OldValue.Name)
			if pathErr != nil {
				eventID = parsed.Data.Value.GetString("event_id")
				if eventID == "" {
					eventID = parsed.Data.OldValue.GetString("event_id")
				}
			}
		}
	}

	if eventID == "" {
		h.logger.Printf("[ERROR] Unable to resolve event_id for event %s", parsed.ID)
		_ = h.guard.MarkFailed(r.Context(), "rsvp_handler", parsed.ID, errors.New("unable to resolve event_id"))
		http.Error(w, "invalid RSVP path or missing event_id", http.StatusBadRequest)
		return
	}

	oldStatus := parsed.Data.OldValue.GetString("status")
	newStatus := parsed.Data.Value.GetString("status")

	deltaGoing, deltaInterested, deltaNotGoing := ComputeRSVPStatusDelta(oldStatus, newStatus)

	if deltaGoing == 0 && deltaInterested == 0 && deltaNotGoing == 0 {
		h.logger.Printf("[INFO] Event %s resulted in zero counter delta (old: '%s', new: '%s'), skipping update", parsed.ID, oldStatus, newStatus)
		if markErr := h.guard.MarkCompleted(r.Context(), "rsvp_handler", parsed.ID); markErr != nil {
			h.logger.Printf("[WARN] Failed to mark event completed: %v", markErr)
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"skipped","reason":"no_status_change"}`))
		return
	}

	if err := h.repo.UpdateEventCounters(r.Context(), eventID, deltaGoing, deltaInterested, deltaNotGoing); err != nil {
		h.logger.Printf("[ERROR] Failed to update event counters for event %s: %v", eventID, err)
		_ = h.guard.MarkFailed(r.Context(), "rsvp_handler", parsed.ID, err)
		http.Error(w, fmt.Sprintf("counter transaction failed: %v", err), http.StatusInternalServerError)
		return
	}

	if markErr := h.guard.MarkCompleted(r.Context(), "rsvp_handler", parsed.ID); markErr != nil {
		h.logger.Printf("[WARN] Failed to mark event completed: %v", markErr)
	}

	h.logger.Printf("[INFO] Successfully updated event counters for event %s (going: %d, interested: %d, not_going: %d)", eventID, deltaGoing, deltaInterested, deltaNotGoing)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{"status":"success","event_id":"%s"}`, eventID)))
}
