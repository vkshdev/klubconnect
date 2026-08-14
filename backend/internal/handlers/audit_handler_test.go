package handlers

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

func TestAuditHandler_HappyPath_BinaryMode(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	actor := "user_456"
	nameVal := "Test Club"
	payload := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: "projects/klubconnect/databases/(default)/documents/clubs/club_101",
			Fields: map[string]models.ValueHolder{
				"name":          {StringValue: &nameVal},
				"actor_user_id": {StringValue: &actor},
			},
		},
	}
	bodyBytes, _ := json.Marshal(payload)

	req, err := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewReader(bodyBytes))
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ce-id", "evt_binary_001")
	req.Header.Set("ce-subject", "documents/clubs/club_101")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
	}

	records := repo.GetRecords()
	if len(records) != 1 {
		t.Fatalf("expected 1 audit record, got %d", len(records))
	}

	rec := records[0]
	if rec.TargetCollection != "clubs" || rec.TargetDocumentID != "club_101" {
		t.Errorf("unexpected target entity: %s/%s", rec.TargetCollection, rec.TargetDocumentID)
	}
	if rec.Action != "CREATE" {
		t.Errorf("expected action CREATE, got %s", rec.Action)
	}
	if rec.ActorID != "user_456" {
		t.Errorf("expected actor user_456, got %s", rec.ActorID)
	}
}

func TestAuditHandler_HappyPath_StructuredMode(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	updater := "user_789"
	envelope := map[string]any{
		"specversion": "1.0",
		"id":          "evt_struct_002",
		"source":      "//firestore.googleapis.com/test",
		"type":        "google.cloud.firestore.document.v1.updated",
		"subject":     "documents/events/event_202",
		"data": models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/klubconnect/databases/(default)/documents/events/event_202",
				Fields: map[string]models.ValueHolder{
					"updated_by": {StringValue: &updater},
				},
			},
			OldValue: models.FirestoreDocument{
				Name: "projects/klubconnect/databases/(default)/documents/events/event_202",
			},
			UpdateMask: models.UpdateMask{
				FieldPaths: []string{"title", "location"},
			},
		},
	}
	bodyBytes, _ := json.Marshal(envelope)

	req, err := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewReader(bodyBytes))
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/cloudevents+json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
	}

	records := repo.GetRecords()
	if len(records) != 1 {
		t.Fatalf("expected 1 audit record, got %d", len(records))
	}

	rec := records[0]
	if rec.Action != "UPDATE" {
		t.Errorf("expected action UPDATE, got %s", rec.Action)
	}
	if len(rec.ChangedFields) != 2 || rec.ChangedFields[0] != "title" {
		t.Errorf("unexpected changed fields: %v", rec.ChangedFields)
	}
}

func TestAuditHandler_DuplicateEvent(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	payload := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: "projects/klubconnect/databases/(default)/documents/clubs/club_101",
		},
	}
	bodyBytes, _ := json.Marshal(payload)

	sendReq := func() int {
		req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewReader(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("ce-id", "evt_dup_001")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()
		return resp.StatusCode
	}

	code1 := sendReq()
	if code1 != http.StatusOK {
		t.Errorf("first request failed with status %d", code1)
	}

	code2 := sendReq()
	if code2 != http.StatusAlreadyReported && code2 != http.StatusOK {
		t.Errorf("second request expected HTTP 208 or 200, got %d", code2)
	}

	records := repo.GetRecords()
	if len(records) != 1 {
		t.Errorf("expected exactly 1 audit record after duplicate call, got %d", len(records))
	}
}

func TestAuditHandler_MalformedPayload(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewBufferString("{invalid-json"))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ce-id", "evt_malformed_001")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected HTTP 400 Bad Request, got %d", resp.StatusCode)
	}

	if len(repo.GetRecords()) != 0 {
		t.Errorf("expected 0 audit records, got %d", len(repo.GetRecords()))
	}
}

func TestAuditHandler_MissingEventID(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewBufferString(`{"data":{}}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected HTTP 400 Bad Request, got %d", resp.StatusCode)
	}
}

func TestAuditHandler_DatabaseError(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	repo.FailWithErr = errors.New("simulated database write error")
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	payload := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: "projects/klubconnect/databases/(default)/documents/clubs/club_err",
		},
	}
	bodyBytes, _ := json.Marshal(payload)

	req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ce-id", "evt_dberr_001")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("expected HTTP 500 Internal Server Error, got %d", resp.StatusCode)
	}
}

func TestAuditHandler_MethodNotAllowed(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	repo := NewMockAuditRepository()
	handler := NewAuditHandler(guard, repo)

	server := httptest.NewServer(handler)
	defer server.Close()

	req, _ := http.NewRequest(http.MethodGet, server.URL+"/events/audit", nil)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("expected HTTP 405 Method Not Allowed, got %d", resp.StatusCode)
	}
}
