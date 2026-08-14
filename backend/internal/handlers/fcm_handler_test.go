package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"firebase.google.com/go/v4/messaging"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

func TestFCMHandler_Success_MulticastDispatched(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	mockRepo.Tokens["user_101"] = []DeviceToken{
		{ID: "dev_1", Token: "token_1", Platform: "android"},
		{ID: "dev_2", Token: "token_2", Platform: "ios"},
	}

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := `{
		"specversion": "1.0",
		"id": "ce_fcm_001",
		"type": "google.cloud.firestore.document.v1.created",
		"data": {
			"value": {
				"name": "projects/p/databases/(default)/documents/notifications/notif_001",
				"fields": {
					"user_id": { "stringValue": "user_101" },
					"title": { "stringValue": "Club Meeting" },
					"body": { "stringValue": "Meeting starts at 5 PM" },
					"type": { "stringValue": "announcement" }
				}
			}
		}
	}`

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(payload))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 OK, got %d. Body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response JSON: %v", err)
	}

	if resp["status"] != "dispatched" {
		t.Errorf("expected status 'dispatched', got '%v'", resp["status"])
	}
	if resp["success_count"].(float64) != 2 {
		t.Errorf("expected success_count 2, got %v", resp["success_count"])
	}

	if mockRepo.UpdatedStatuses["notif_001"] != "dispatched" {
		t.Errorf("expected mock repo status 'dispatched', got '%s'", mockRepo.UpdatedStatuses["notif_001"])
	}
}

func TestFCMHandler_ZeroTokens_SkippedGracefully(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	mockRepo.Tokens["user_102"] = []DeviceToken{}

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := `{
		"specversion": "1.0",
		"id": "ce_fcm_002",
		"type": "google.cloud.firestore.document.v1.created",
		"data": {
			"value": {
				"name": "projects/p/databases/(default)/documents/notifications/notif_002",
				"fields": {
					"user_id": { "stringValue": "user_102" },
					"title": { "stringValue": "Reminder" },
					"body": { "stringValue": "Zero token test" }
				}
			}
		}
	}`

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(payload))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 OK, got %d. Body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)

	if resp["status"] != "skipped" {
		t.Errorf("expected status 'skipped', got '%v'", resp["status"])
	}
	if resp["reason"] != "no_active_device_tokens" {
		t.Errorf("expected reason 'no_active_device_tokens', got '%v'", resp["reason"])
	}

	if len(mockFCM.GetSentMessages()) != 0 {
		t.Errorf("expected 0 FCM messages sent, got %d", len(mockFCM.GetSentMessages()))
	}
	if mockRepo.UpdatedStatuses["notif_002"] != "skipped" {
		t.Errorf("expected repo notification status 'skipped', got '%s'", mockRepo.UpdatedStatuses["notif_002"])
	}
}

func TestFCMHandler_DuplicateRequest(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	ctx := context.Background()
	_, _ = guard.LockOrSkip(ctx, "FCMHandler", "ce_fcm_dup")
	_ = guard.MarkCompleted(ctx, "FCMHandler", "ce_fcm_dup")

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := `{
		"specversion": "1.0",
		"id": "ce_fcm_dup",
		"type": "google.cloud.firestore.document.v1.created",
		"data": {
			"value": {
				"name": "projects/p/databases/(default)/documents/notifications/notif_dup",
				"fields": {
					"user_id": { "stringValue": "user_101" }
				}
			}
		}
	}`

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(payload))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 OK, got %d", rec.Code)
	}

	var resp map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)

	if resp["status"] != "already_processed" {
		t.Errorf("expected status 'already_processed', got '%v'", resp["status"])
	}
	if len(mockFCM.GetSentMessages()) != 0 {
		t.Errorf("expected 0 FCM messages sent, got %d", len(mockFCM.GetSentMessages()))
	}
}

func TestFCMHandler_StaleTokens_AutoPruned(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	mockRepo.Tokens["user_103"] = []DeviceToken{
		{ID: "tok_1", Token: "t1"},
		{ID: "tok_2", Token: "t2"},
		{ID: "tok_3", Token: "t3"},
	}

	mockFCM.SendFn = func(ctx context.Context, message *messaging.MulticastMessage) (*messaging.BatchResponse, error) {
		return &messaging.BatchResponse{
			SuccessCount: 1,
			FailureCount: 2,
			Responses: []*messaging.SendResponse{
				{Success: true, MessageID: "msg_1"},
				{Success: false, Error: errors.New("Unregistered registration token")},
				{Success: false, Error: errors.New("InvalidArgument token")},
			},
		}, nil
	}

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := `{
		"specversion": "1.0",
		"id": "ce_fcm_prune",
		"type": "google.cloud.firestore.document.v1.created",
		"data": {
			"value": {
				"name": "projects/p/databases/(default)/documents/notifications/notif_prune",
				"fields": {
					"user_id": { "stringValue": "user_103" }
				}
			}
		}
	}`

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(payload))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 OK, got %d", rec.Code)
	}

	var resp map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)

	if resp["status"] != "dispatched" {
		t.Errorf("expected status 'dispatched', got '%v'", resp["status"])
	}
	if resp["pruned_tokens"].(float64) != 2 {
		t.Errorf("expected 2 pruned tokens, got %v", resp["pruned_tokens"])
	}

	if len(mockRepo.DeletedTokens) != 2 {
		t.Fatalf("expected 2 deleted tokens in mock repo, got %d", len(mockRepo.DeletedTokens))
	}
	if mockRepo.DeletedTokens[0] != "tok_2" || mockRepo.DeletedTokens[1] != "tok_3" {
		t.Errorf("unexpected deleted tokens: %v", mockRepo.DeletedTokens)
	}
}

func TestFCMHandler_AllTokensFailed(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	mockRepo.Tokens["user_104"] = []DeviceToken{
		{ID: "tok_fail1", Token: "t_fail1"},
		{ID: "tok_fail2", Token: "t_fail2"},
	}

	mockFCM.SendFn = func(ctx context.Context, message *messaging.MulticastMessage) (*messaging.BatchResponse, error) {
		return &messaging.BatchResponse{
			SuccessCount: 0,
			FailureCount: 2,
			Responses: []*messaging.SendResponse{
				{Success: false, Error: errors.New("network error")},
				{Success: false, Error: errors.New("network error")},
			},
		}, nil
	}

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := `{
		"specversion": "1.0",
		"id": "ce_fcm_allfail",
		"type": "google.cloud.firestore.document.v1.created",
		"data": {
			"value": {
				"name": "projects/p/databases/(default)/documents/notifications/notif_allfail",
				"fields": {
					"user_id": { "stringValue": "user_104" }
				}
			}
		}
	}`

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(payload))
	req.Header.Set("Content-Type", "application/cloudevents+json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 OK, got %d", rec.Code)
	}

	var resp map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)

	if resp["status"] != "failed" {
		t.Errorf("expected status 'failed', got '%v'", resp["status"])
	}
	if mockRepo.UpdatedStatuses["notif_allfail"] != "failed" {
		t.Errorf("expected repo notification status 'failed', got '%s'", mockRepo.UpdatedStatuses["notif_allfail"])
	}
}

func TestFCMHandler_MalformedPayload(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewBufferString(`{bad-json`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ce-id", "ce_bad_001")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected HTTP 400 Bad Request, got %d", rec.Code)
	}
}

func TestFCMHandler_FCMClientError(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	mockFCM := NewMockFCMClient()
	mockRepo := NewMockFirestoreRepository()

	mockRepo.Tokens["user_105"] = []DeviceToken{
		{ID: "tok_err", Token: "t_err"},
	}
	mockFCM.FailWithErr = errors.New("FCM service unavailable")

	handler := NewFCMHandler(guard, mockFCM, mockRepo)

	payload := models.DocumentEventData{
		Value: models.FirestoreDocument{
			Name: "projects/p/databases/(default)/documents/notifications/notif_err",
			Fields: map[string]models.ValueHolder{
				"user_id": {StringValue: func(s string) *string { return &s }("user_105")},
			},
		},
	}
	bodyBytes, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/events/fcm", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("ce-id", "ce_fcmerr_001")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("expected HTTP 500 Internal Server Error, got %d", rec.Code)
	}
	if mockRepo.UpdatedStatuses["notif_err"] != "failed" {
		t.Errorf("expected repo status 'failed', got '%s'", mockRepo.UpdatedStatuses["notif_err"])
	}
}
