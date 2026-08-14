package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

type MockMembershipRepository struct {
	mu               sync.Mutex
	UserInstitutions map[string]string
	ClubInstitutions map[string]string
	UserErr          error
	ClubErr          error
	BatchErr         error

	ExecutedBatches []MembershipApprovalBatchParams
}

func NewMockMembershipRepository() *MockMembershipRepository {
	return &MockMembershipRepository{
		UserInstitutions: make(map[string]string),
		ClubInstitutions: make(map[string]string),
	}
}

func (m *MockMembershipRepository) GetUserInstitution(ctx context.Context, userID string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.UserErr != nil {
		return "", m.UserErr
	}
	inst, ok := m.UserInstitutions[userID]
	if !ok {
		return "", errors.New("user not found")
	}
	return inst, nil
}

func (m *MockMembershipRepository) GetClubInstitution(ctx context.Context, clubID string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.ClubErr != nil {
		return "", m.ClubErr
	}
	inst, ok := m.ClubInstitutions[clubID]
	if !ok {
		return "", errors.New("club not found")
	}
	return inst, nil
}

func (m *MockMembershipRepository) ExecuteMembershipApprovalBatch(ctx context.Context, params MembershipApprovalBatchParams) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.BatchErr != nil {
		return m.BatchErr
	}
	m.ExecutedBatches = append(m.ExecutedBatches, params)
	return nil
}

func makeMembershipCloudEventRequest(ceID, membershipID, userID, clubID, instID, oldStatus, newStatus string) (*http.Request, error) {
	docPath := fmt.Sprintf("projects/p/databases/(default)/documents/memberships/%s", membershipID)
	docData := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: docPath,
			Fields: map[string]models.ValueHolder{
				"membership_id":  {StringValue: &membershipID},
				"user_id":        {StringValue: &userID},
				"club_id":        {StringValue: &clubID},
				"institution_id": {StringValue: &instID},
				"status":         {StringValue: &newStatus},
			},
		},
		OldValue: models.FirestoreDocument{
			Name: docPath,
			Fields: map[string]models.ValueHolder{
				"membership_id":  {StringValue: &membershipID},
				"user_id":        {StringValue: &userID},
				"club_id":        {StringValue: &clubID},
				"institution_id": {StringValue: &instID},
				"status":         {StringValue: &oldStatus},
			},
		},
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

	req := httptest.NewRequest("POST", "/events/membership", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	return req, nil
}

func TestMembershipHandler_Success(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	repo.UserInstitutions["usr-100"] = "inst-100"
	repo.ClubInstitutions["club-200"] = "inst-100"

	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-1", "mem-300", "usr-100", "club-200", "inst-100", "pending", "approved")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	if len(repo.ExecutedBatches) != 1 {
		t.Fatalf("Expected 1 batch execution, got %d", len(repo.ExecutedBatches))
	}

	batch := repo.ExecutedBatches[0]
	if batch.MembershipID != "mem-300" || batch.UserID != "usr-100" || batch.ClubID != "club-200" || batch.InstitutionID != "inst-100" {
		t.Errorf("Unexpected batch params: %+v", batch)
	}
}

func TestMembershipHandler_PreconditionSkip_NotApproved(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-2", "mem-300", "usr-100", "club-200", "inst-100", "pending", "rejected")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if !bytes.Contains(rr.Body.Bytes(), []byte("precondition_not_met")) {
		t.Errorf("Expected precondition_not_met in response body, got %s", rr.Body.String())
	}

	if len(repo.ExecutedBatches) != 0 {
		t.Errorf("Expected 0 batch executions for rejected transition, got %d", len(repo.ExecutedBatches))
	}
}

func TestMembershipHandler_PreconditionSkip_AlreadyApproved(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-3", "mem-300", "usr-100", "club-200", "inst-100", "approved", "approved")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	if !bytes.Contains(rr.Body.Bytes(), []byte("precondition_not_met")) {
		t.Errorf("Expected precondition_not_met in response body, got %s", rr.Body.String())
	}

	if len(repo.ExecutedBatches) != 0 {
		t.Errorf("Expected 0 batch executions for approved->approved transition, got %d", len(repo.ExecutedBatches))
	}
}

func TestMembershipHandler_MultiTenantViolation_UserMismatch(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	repo.UserInstitutions["usr-100"] = "inst-AAA"
	repo.ClubInstitutions["club-200"] = "inst-BBB"

	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-4", "mem-300", "usr-100", "club-200", "inst-AAA", "pending", "approved")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("Expected status 403 Forbidden, got %d: %s", rr.Code, rr.Body.String())
	}

	if len(repo.ExecutedBatches) != 0 {
		t.Errorf("Expected 0 batch executions on multi-tenant violation, got %d", len(repo.ExecutedBatches))
	}
}

func TestMembershipHandler_MultiTenantViolation_MembershipMismatch(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	repo.UserInstitutions["usr-100"] = "inst-AAA"
	repo.ClubInstitutions["club-200"] = "inst-AAA"

	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-5", "mem-300", "usr-100", "club-200", "inst-CCC", "pending", "approved")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Errorf("Expected status 403 Forbidden, got %d", rr.Code)
	}

	if len(repo.ExecutedBatches) != 0 {
		t.Errorf("Expected 0 batch executions on membership institution mismatch, got %d", len(repo.ExecutedBatches))
	}
}

func TestMembershipHandler_DuplicateEvent_Idempotency(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	repo.UserInstitutions["usr-100"] = "inst-100"
	repo.ClubInstitutions["club-200"] = "inst-100"

	handler := NewMembershipHandler(guard, repo)

	req1, _ := makeMembershipCloudEventRequest("ce-dup-mem", "mem-300", "usr-100", "club-200", "inst-100", "pending", "approved")
	rr1 := httptest.NewRecorder()
	handler.ServeHTTP(rr1, req1)
	if rr1.Code != http.StatusOK {
		t.Fatalf("First request failed: %d", rr1.Code)
	}

	req2, _ := makeMembershipCloudEventRequest("ce-dup-mem", "mem-300", "usr-100", "club-200", "inst-100", "pending", "approved")
	rr2 := httptest.NewRecorder()
	handler.ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusOK {
		t.Fatalf("Duplicate request failed: %d", rr2.Code)
	}

	if !bytes.Contains(rr2.Body.Bytes(), []byte("duplicate_event")) {
		t.Errorf("Expected duplicate_event response, got: %s", rr2.Body.String())
	}

	if len(repo.ExecutedBatches) != 1 {
		t.Errorf("Expected 1 batch execution total (duplicate skipped), got %d", len(repo.ExecutedBatches))
	}
}

func TestMembershipHandler_InvalidPayload(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	handler := NewMembershipHandler(guard, repo)

	req := httptest.NewRequest("POST", "/events/membership", bytes.NewReader([]byte(`{"invalid":"json"`)))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400 Bad Request, got %d", rr.Code)
	}
}

func TestMembershipHandler_DatabaseWriteError(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	repo.UserInstitutions["usr-100"] = "inst-100"
	repo.ClubInstitutions["club-200"] = "inst-100"
	repo.BatchErr = errors.New("simulated batch write failure")

	handler := NewMembershipHandler(guard, repo)

	req, err := makeMembershipCloudEventRequest("ce-mem-err", "mem-300", "usr-100", "club-200", "inst-100", "pending", "approved")
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500 Internal Server Error, got %d", rr.Code)
	}
}

func TestMembershipHandler_MethodNotAllowed(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockMembershipRepository()
	handler := NewMembershipHandler(guard, repo)

	req := httptest.NewRequest("GET", "/events/membership", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status 405 Method Not Allowed, got %d", rr.Code)
	}
}
