package idempotency

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// MemoryGuard provides a thread-safe in-memory implementation of Guard for unit tests.
type MemoryGuard struct {
	mu      sync.Mutex
	states  map[string]*EventState
	lockTTL time.Duration
}

// NewMemoryGuard initializes a MemoryGuard instance.
func NewMemoryGuard() *MemoryGuard {
	return &MemoryGuard{
		states:  make(map[string]*EventState),
		lockTTL: 5 * time.Minute,
	}
}

func (m *MemoryGuard) key(handlerName, eventID string) string {
	return fmt.Sprintf("%s_%s", handlerName, eventID)
}

func (m *MemoryGuard) LockOrSkip(ctx context.Context, handlerName, eventID string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	k := m.key(handlerName, eventID)
	state, exists := m.states[k]
	now := time.Now().UTC()

	if exists {
		if state.Status == StatusCompleted {
			return true, nil
		}
		if state.Status == StatusPending {
			if now.Sub(state.ProcessedAt) < m.lockTTL {
				return true, nil
			}
			state.Attempt++
			state.Status = StatusPending
			state.ProcessedAt = now
			return false, nil
		}
		state.Attempt++
		state.Status = StatusPending
		state.ProcessedAt = now
		return false, nil
	}

	m.states[k] = &EventState{
		EventID:     eventID,
		HandlerName: handlerName,
		Status:      StatusPending,
		ProcessedAt: now,
		Attempt:     1,
	}
	return false, nil
}

func (m *MemoryGuard) MarkCompleted(ctx context.Context, handlerName, eventID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	k := m.key(handlerName, eventID)
	state, exists := m.states[k]
	if !exists {
		state = &EventState{
			EventID:     eventID,
			HandlerName: handlerName,
			Attempt:     1,
		}
		m.states[k] = state
	}

	state.Status = StatusCompleted
	state.ProcessedAt = time.Now().UTC()
	state.Error = ""
	return nil
}

func (m *MemoryGuard) MarkFailed(ctx context.Context, handlerName, eventID string, execErr error) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	k := m.key(handlerName, eventID)
	state, exists := m.states[k]
	if !exists {
		state = &EventState{
			EventID:     eventID,
			HandlerName: handlerName,
			Attempt:     1,
		}
		m.states[k] = state
	}

	state.Status = StatusFailed
	state.ProcessedAt = time.Now().UTC()
	if execErr != nil {
		state.Error = execErr.Error()
	}
	return nil
}

func (m *MemoryGuard) Execute(ctx context.Context, handlerName, eventID string, fn func(ctx context.Context) error) error {
	return ExecuteGuard(ctx, m, handlerName, eventID, fn)
}
