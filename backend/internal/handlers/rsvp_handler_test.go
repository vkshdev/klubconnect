package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

type MockRSVPRepository struct {
	mu            sync.Mutex
	Counters      map[string]map[string]int64
	ShouldFailErr error
}

func NewMockRSVPRepository() *MockRSVPRepository {
	return &MockRSVPRepository{
		Counters: make(map[string]map[string]int64),
	}
}

func (m *MockRSVPRepository) UpdateEventCounters(ctx context.Context, eventID string, deltaGoing, deltaInterested, deltaNotGoing int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.ShouldFailErr != nil {
		return m.ShouldFailErr
	}

	if _, ok := m.Counters[eventID]; !ok {
		m.Counters[eventID] = map[string]int64{
			"current_participants": 0,
			"interested_count":     0,
			"not_going_count":      0,
		}
	}

	m.Counters[eventID]["current_participants"] += deltaGoing
	m.Counters[eventID]["interested_count"] += deltaInterested
	m.Counters[eventID]["not_going_count"] += deltaNotGoing
	return nil
}

func makeRSVPCloudEventRequest(ceID, docPath, oldStatus, newStatus string, binaryMode bool) (*http.Request, error) {
	docData := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: docPath,
			Fields: map[string]models.ValueHolder{
				"status": {StringValue: &newStatus},
			},
		},
	}
	if oldStatus != "" {
		docData.OldValue = models.FirestoreDocument{
			Name: docPath,
			Fields: map[string]models.ValueHolder{
				"status": {StringValue: &oldStatus},
			},
		}
	}

	if binaryMode {
		bodyBytes, err := json.Marshal(docData)
		if err != nil {
			return nil, err
		}
		req := httptest.NewRequest("POST", "/events/rsvp", bytes.NewReader(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("ce-id", ceID)
		req.Header.Set("ce-subject", docPath)
		return req, nil
	}

	ce := models.CloudEvent[models.DocumentEventData]{
		SpecVersion: "1.0",
		ID:          ceID,
		Source:      "//firestore.googleapis.com",
		Type:        "google.cloud.firestore.document.v1.updated",
		Subject:     docPath,
		Time:        time.Now().UTC(),
		Data:        docData,
	}

	bodyBytes, err := json.Marshal(ce)
	if err != nil {
		return nil, err
	}

	req := httptest.NewRequest("POST", "/events/rsvp", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	return req, nil
}

func TestRSVPHandler_CreateGoing(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-1", "projects/p/databases/(default)/documents/events/evt-100/rsvps/usr-1", "", "going", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	if repo.Counters["evt-100"]["current_participants"] != 1 {
		t.Errorf("Expected current_participants=1, got %d", repo.Counters["evt-100"]["current_participants"])
	}
}

func TestRSVPHandler_UpdateGoingToNotGoing(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-2", "projects/p/databases/(default)/documents/events/evt-100/rsvps/usr-1", "going", "not_going", true)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if repo.Counters["evt-100"]["current_participants"] != -1 {
		t.Errorf("Expected current_participants=-1, got %d", repo.Counters["evt-100"]["current_participants"])
	}
	if repo.Counters["evt-100"]["not_going_count"] != 1 {
		t.Errorf("Expected not_going_count=1, got %d", repo.Counters["evt-100"]["not_going_count"])
	}
}

func TestRSVPHandler_UpdateInterestedToGoing(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-3", "documents/events/evt-200/rsvps/usr-2", "interested", "going", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if repo.Counters["evt-200"]["current_participants"] != 1 {
		t.Errorf("Expected current_participants=1, got %d", repo.Counters["evt-200"]["current_participants"])
	}
	if repo.Counters["evt-200"]["interested_count"] != -1 {
		t.Errorf("Expected interested_count=-1, got %d", repo.Counters["evt-200"]["interested_count"])
	}
}

func TestRSVPHandler_NoOpUpdate(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-4", "documents/events/evt-100/rsvps/usr-1", "going", "going", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if _, ok := repo.Counters["evt-100"]; ok {
		t.Errorf("Expected no counter updates for no-op transition, but counter entry was created")
	}
}

func TestRSVPHandler_DuplicateCloudEvent(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req1, _ := makeRSVPCloudEventRequest("evt-dup", "documents/events/evt-100/rsvps/usr-1", "", "going", false)
	rr1 := httptest.NewRecorder()
	handler.ServeHTTP(rr1, req1)
	if rr1.Code != http.StatusOK {
		t.Fatalf("First request failed: %d", rr1.Code)
	}

	req2, _ := makeRSVPCloudEventRequest("evt-dup", "documents/events/evt-100/rsvps/usr-1", "", "going", false)
	rr2 := httptest.NewRecorder()
	handler.ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusOK {
		t.Fatalf("Duplicate request failed: %d", rr2.Code)
	}

	if !bytes.Contains(rr2.Body.Bytes(), []byte("duplicate_event")) {
		t.Errorf("Expected duplicate_event response body, got: %s", rr2.Body.String())
	}

	if repo.Counters["evt-100"]["current_participants"] != 1 {
		t.Errorf("Expected current_participants=1 (processed once), got %d", repo.Counters["evt-100"]["current_participants"])
	}
}

func TestRSVPHandler_InvalidPath(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-badpath", "documents/invalid/path", "", "going", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400 Bad Request, got %d", rr.Code)
	}
}

func TestRSVPHandler_TransactionFailure(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	repo.ShouldFailErr = errors.New("simulated transaction failure")
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-txfail", "documents/events/evt-100/rsvps/usr-1", "", "going", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500 Internal Server Error, got %d", rr.Code)
	}
}

func TestRSVPHandler_MethodNotAllowed(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req := httptest.NewRequest("GET", "/events/rsvp", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status 405 Method Not Allowed, got %d", rr.Code)
	}
}

func TestRSVPHandler_DeleteRSVP(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockRSVPRepository()
	handler := NewRSVPHandler(guard, repo)

	req, err := makeRSVPCloudEventRequest("evt-del", "documents/events/evt-100/rsvps/usr-1", "going", "", false)
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if repo.Counters["evt-100"]["current_participants"] != -1 {
		t.Errorf("Expected current_participants=-1, got %d", repo.Counters["evt-100"]["current_participants"])
	}
}
