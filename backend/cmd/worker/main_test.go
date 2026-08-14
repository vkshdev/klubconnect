package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"klubconnect/backend/internal/handlers"
	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

type TestFixtures struct {
	Guard          *idempotency.MemoryGuard
	AuditRepo      *handlers.MockAuditRepository
	FCMClient      *handlers.MockFCMClient
	FCMRepo        *handlers.MockFirestoreRepository
	RSVPRepo       *MockRSVPRepository
	MembershipRepo *MockMembershipRepository
}

func setupTestServer(t *testing.T) (*httptest.Server, *TestFixtures) {
	t.Helper()

	guard := idempotency.NewMemoryGuard()
	auditRepo := handlers.NewMockAuditRepository()
	fcmClient := handlers.NewMockFCMClient()
	fcmRepo := handlers.NewMockFirestoreRepository()
	rsvpRepo := NewMockRSVPRepository()
	membershipRepo := NewMockMembershipRepository()

	router := BuildRouter(guard, auditRepo, fcmClient, fcmRepo, rsvpRepo, membershipRepo)
	server := httptest.NewServer(router)

	fixtures := &TestFixtures{
		Guard:          guard,
		AuditRepo:      auditRepo,
		FCMClient:      fcmClient,
		FCMRepo:        fcmRepo,
		RSVPRepo:       rsvpRepo,
		MembershipRepo: membershipRepo,
	}

	return server, fixtures
}

func TestE2E_BinaryCloudEvents(t *testing.T) {
	server, fixtures := setupTestServer(t)
	defer server.Close()

	t.Run("POST /events/audit", func(t *testing.T) {
		actor := "usr_bin_1"
		nameVal := "Binary Club"
		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/clubs/club_bin_1",
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
		req.Header.Set("ce-id", "bin-audit-1")
		req.Header.Set("ce-type", "google.cloud.firestore.document.v1.created")
		req.Header.Set("ce-source", "//firestore.googleapis.com")
		req.Header.Set("ce-specversion", "1.0")
		req.Header.Set("ce-subject", "documents/clubs/club_bin_1")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
		}

		records := fixtures.AuditRepo.GetRecords()
		if len(records) != 1 {
			t.Fatalf("expected 1 audit record, got %d", len(records))
		}
		if records[0].TargetDocumentID != "club_bin_1" {
			t.Errorf("expected target document club_bin_1, got %s", records[0].TargetDocumentID)
		}
	})

	t.Run("POST /events/fcm", func(t *testing.T) {
		fixtures.FCMRepo.Tokens["usr_fcm_bin"] = []handlers.DeviceToken{
			{ID: "dt-1", Token: "fcm-tok-123"},
		}

		userVal := "usr_fcm_bin"
		titleVal := "Test Title"
		bodyVal := "Test Body"
		typeVal := "announcement"
		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/notifications/notif_bin_1",
				Fields: map[string]models.ValueHolder{
					"user_id": {StringValue: &userVal},
					"title":   {StringValue: &titleVal},
					"body":    {StringValue: &bodyVal},
					"type":    {StringValue: &typeVal},
				},
			},
		}
		bodyBytes, _ := json.Marshal(payload)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/fcm", bytes.NewReader(bodyBytes))
		if err != nil {
			t.Fatalf("failed to create request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("ce-id", "bin-fcm-1")
		req.Header.Set("ce-type", "google.cloud.firestore.document.v1.created")
		req.Header.Set("ce-source", "//firestore.googleapis.com")
		req.Header.Set("ce-specversion", "1.0")
		req.Header.Set("ce-subject", "documents/notifications/notif_bin_1")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
		}

		if len(fixtures.FCMClient.GetSentMessages()) != 1 {
			t.Errorf("expected 1 sent FCM message, got %d", len(fixtures.FCMClient.GetSentMessages()))
		}
	})

	t.Run("POST /events/rsvp", func(t *testing.T) {
		statusVal := "going"
		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/events/evt_bin_10/rsvps/usr_bin_2",
				Fields: map[string]models.ValueHolder{
					"status": {StringValue: &statusVal},
				},
			},
		}
		bodyBytes, _ := json.Marshal(payload)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/rsvp", bytes.NewReader(bodyBytes))
		if err != nil {
			t.Fatalf("failed to create request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("ce-id", "bin-rsvp-1")
		req.Header.Set("ce-type", "google.cloud.firestore.document.v1.created")
		req.Header.Set("ce-source", "//firestore.googleapis.com")
		req.Header.Set("ce-specversion", "1.0")
		req.Header.Set("ce-subject", "documents/events/evt_bin_10/rsvps/usr_bin_2")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
		}

		if fixtures.RSVPRepo.Counters["evt_bin_10"]["current_participants"] != 1 {
			t.Errorf("expected counter current_participants=1, got %d", fixtures.RSVPRepo.Counters["evt_bin_10"]["current_participants"])
		}
	})

	t.Run("POST /events/membership", func(t *testing.T) {
		fixtures.MembershipRepo.UserInstitutions["usr_mem_bin"] = "inst_bin_1"
		fixtures.MembershipRepo.ClubInstitutions["club_mem_bin"] = "inst_bin_1"

		memID := "mem_bin_1"
		usrID := "usr_mem_bin"
		clubID := "club_mem_bin"
		instID := "inst_bin_1"
		newStat := "approved"
		oldStat := "pending"

		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/memberships/mem_bin_1",
				Fields: map[string]models.ValueHolder{
					"membership_id":  {StringValue: &memID},
					"user_id":        {StringValue: &usrID},
					"club_id":        {StringValue: &clubID},
					"institution_id": {StringValue: &instID},
					"status":         {StringValue: &newStat},
				},
			},
			OldValue: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/memberships/mem_bin_1",
				Fields: map[string]models.ValueHolder{
					"status": {StringValue: &oldStat},
				},
			},
		}
		bodyBytes, _ := json.Marshal(payload)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/membership", bytes.NewReader(bodyBytes))
		if err != nil {
			t.Fatalf("failed to create request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("ce-id", "bin-mem-1")
		req.Header.Set("ce-type", "google.cloud.firestore.document.v1.updated")
		req.Header.Set("ce-source", "//firestore.googleapis.com")
		req.Header.Set("ce-specversion", "1.0")
		req.Header.Set("ce-subject", "documents/memberships/mem_bin_1")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("expected HTTP 200 OK, got %d", resp.StatusCode)
		}

		if len(fixtures.MembershipRepo.ExecutedBatches) != 1 {
			t.Errorf("expected 1 membership approval batch execution, got %d", len(fixtures.MembershipRepo.ExecutedBatches))
		}
	})
}

func TestE2E_StructuredCloudEvents(t *testing.T) {
	server, fixtures := setupTestServer(t)
	defer server.Close()

	t.Run("POST /events/audit", func(t *testing.T) {
		updater := "usr_struct_1"
		envelope := models.CloudEvent[models.DocumentEventData]{
			SpecVersion: "1.0",
			ID:          "struct-audit-1",
			Source:      "//firestore.googleapis.com",
			Type:        "google.cloud.firestore.document.v1.updated",
			Subject:     "documents/events/evt_struct_1",
			Data: models.DocumentEventData{
				Value: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/events/evt_struct_1",
					Fields: map[string]models.ValueHolder{
						"updated_by": {StringValue: &updater},
					},
				},
				OldValue: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/events/evt_struct_1",
				},
				UpdateMask: models.UpdateMask{
					FieldPaths: []string{"title"},
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

		records := fixtures.AuditRepo.GetRecords()
		if len(records) != 1 {
			t.Fatalf("expected 1 audit record, got %d", len(records))
		}
	})

	t.Run("POST /events/fcm", func(t *testing.T) {
		fixtures.FCMRepo.Tokens["usr_fcm_struct"] = []handlers.DeviceToken{
			{ID: "dt-2", Token: "fcm-tok-456"},
		}

		userVal := "usr_fcm_struct"
		titleVal := "Welcome"
		bodyVal := "Welcome aboard"
		typeVal := "welcome"

		envelope := models.CloudEvent[models.DocumentEventData]{
			SpecVersion: "1.0",
			ID:          "struct-fcm-1",
			Source:      "//firestore.googleapis.com",
			Type:        "google.cloud.firestore.document.v1.created",
			Subject:     "documents/notifications/notif_struct_1",
			Data: models.DocumentEventData{
				Value: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/notifications/notif_struct_1",
					Fields: map[string]models.ValueHolder{
						"user_id": {StringValue: &userVal},
						"title":   {StringValue: &titleVal},
						"body":    {StringValue: &bodyVal},
						"type":    {StringValue: &typeVal},
					},
				},
			},
		}
		bodyBytes, _ := json.Marshal(envelope)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/fcm", bytes.NewReader(bodyBytes))
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

		if len(fixtures.FCMClient.GetSentMessages()) != 1 {
			t.Errorf("expected 1 sent FCM message, got %d", len(fixtures.FCMClient.GetSentMessages()))
		}
	})

	t.Run("POST /events/rsvp", func(t *testing.T) {
		newStat := "interested"
		oldStat := "going"
		envelope := models.CloudEvent[models.DocumentEventData]{
			SpecVersion: "1.0",
			ID:          "struct-rsvp-1",
			Source:      "//firestore.googleapis.com",
			Type:        "google.cloud.firestore.document.v1.updated",
			Subject:     "documents/events/evt_struct_20/rsvps/usr_struct_2",
			Data: models.DocumentEventData{
				Value: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/events/evt_struct_20/rsvps/usr_struct_2",
					Fields: map[string]models.ValueHolder{
						"status": {StringValue: &newStat},
					},
				},
				OldValue: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/events/evt_struct_20/rsvps/usr_struct_2",
					Fields: map[string]models.ValueHolder{
						"status": {StringValue: &oldStat},
					},
				},
			},
		}
		bodyBytes, _ := json.Marshal(envelope)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/rsvp", bytes.NewReader(bodyBytes))
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

		if fixtures.RSVPRepo.Counters["evt_struct_20"]["interested_count"] != 1 {
			t.Errorf("expected interested_count=1, got %d", fixtures.RSVPRepo.Counters["evt_struct_20"]["interested_count"])
		}
	})

	t.Run("POST /events/membership", func(t *testing.T) {
		fixtures.MembershipRepo.UserInstitutions["usr_mem_struct"] = "inst_struct_1"
		fixtures.MembershipRepo.ClubInstitutions["club_mem_struct"] = "inst_struct_1"

		memID := "mem_struct_1"
		usrID := "usr_mem_struct"
		clubID := "club_mem_struct"
		instID := "inst_struct_1"
		newStat := "approved"
		oldStat := "pending"

		envelope := models.CloudEvent[models.DocumentEventData]{
			SpecVersion: "1.0",
			ID:          "struct-mem-1",
			Source:      "//firestore.googleapis.com",
			Type:        "google.cloud.firestore.document.v1.updated",
			Subject:     "documents/memberships/mem_struct_1",
			Data: models.DocumentEventData{
				Value: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/memberships/mem_struct_1",
					Fields: map[string]models.ValueHolder{
						"membership_id":  {StringValue: &memID},
						"user_id":        {StringValue: &usrID},
						"club_id":        {StringValue: &clubID},
						"institution_id": {StringValue: &instID},
						"status":         {StringValue: &newStat},
					},
				},
				OldValue: models.FirestoreDocument{
					Name: "projects/p/databases/(default)/documents/memberships/mem_struct_1",
					Fields: map[string]models.ValueHolder{
						"status": {StringValue: &oldStat},
					},
				},
			},
		}
		bodyBytes, _ := json.Marshal(envelope)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/events/membership", bytes.NewReader(bodyBytes))
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

		if len(fixtures.MembershipRepo.ExecutedBatches) != 1 {
			t.Errorf("expected 1 membership batch execution, got %d", len(fixtures.MembershipRepo.ExecutedBatches))
		}
	})
}

func TestE2E_IdempotencyDeduplication(t *testing.T) {
	server, fixtures := setupTestServer(t)
	defer server.Close()

	t.Run("Audit endpoint idempotency deduplication", func(t *testing.T) {
		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/clubs/club_dup_1",
			},
		}
		bodyBytes, _ := json.Marshal(payload)

		sendReq := func() int {
			req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/audit", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("ce-id", "idemp-audit-dup-001")
			req.Header.Set("ce-subject", "documents/clubs/club_dup_1")
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()
			return resp.StatusCode
		}

		status1 := sendReq()
		if status1 != http.StatusOK {
			t.Fatalf("first request failed: expected status 200, got %d", status1)
		}

		status2 := sendReq()
		if status2 != http.StatusAlreadyReported && status2 != http.StatusOK {
			t.Errorf("second request expected HTTP 208 or HTTP 200, got %d", status2)
		}

		records := fixtures.AuditRepo.GetRecords()
		if len(records) != 1 {
			t.Errorf("expected exactly 1 audit record despite duplicate request, got %d", len(records))
		}
	})

	t.Run("FCM endpoint idempotency deduplication", func(t *testing.T) {
		fixtures.FCMRepo.Tokens["usr_fcm_dup"] = []handlers.DeviceToken{
			{ID: "dt-dup", Token: "fcm-tok-dup"},
		}

		userVal := "usr_fcm_dup"
		payload := models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/notifications/notif_dup_1",
				Fields: map[string]models.ValueHolder{
					"user_id": {StringValue: &userVal},
				},
			},
		}
		bodyBytes, _ := json.Marshal(payload)

		sendReq := func() int {
			req, _ := http.NewRequest(http.MethodPost, server.URL+"/events/fcm", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("ce-id", "idemp-fcm-dup-001")
			req.Header.Set("ce-subject", "documents/notifications/notif_dup_1")
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()
			return resp.StatusCode
		}

		status1 := sendReq()
		if status1 != http.StatusOK {
			t.Fatalf("first request failed: expected status 200, got %d", status1)
		}

		status2 := sendReq()
		if status2 != http.StatusOK {
			t.Errorf("second request expected HTTP 200, got %d", status2)
		}

		if len(fixtures.FCMClient.GetSentMessages()) != 1 {
			t.Errorf("expected exactly 1 sent message despite duplicate request, got %d", len(fixtures.FCMClient.GetSentMessages()))
		}
	})
}

func TestE2E_MalformedPayloadValidation(t *testing.T) {
	server, fixtures := setupTestServer(t)
	defer server.Close()

	endpoints := []string{"/events/audit", "/events/fcm", "/events/rsvp", "/events/membership"}

	for _, ep := range endpoints {
		t.Run("Malformed JSON on "+ep, func(t *testing.T) {
			req, _ := http.NewRequest(http.MethodPost, server.URL+ep, bytes.NewBufferString("{bad-json-payload"))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("ce-id", "malformed-ce-1")

			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("expected status HTTP 400 Bad Request on %s, got %d", ep, resp.StatusCode)
			}
		})
	}

	if len(fixtures.AuditRepo.GetRecords()) != 0 {
		t.Errorf("expected 0 audit records on malformed payload, got %d", len(fixtures.AuditRepo.GetRecords()))
	}
	if len(fixtures.FCMClient.GetSentMessages()) != 0 {
		t.Errorf("expected 0 sent FCM messages on malformed payload, got %d", len(fixtures.FCMClient.GetSentMessages()))
	}
	if len(fixtures.MembershipRepo.ExecutedBatches) != 0 {
		t.Errorf("expected 0 membership batch executions on malformed payload, got %d", len(fixtures.MembershipRepo.ExecutedBatches))
	}
}

func TestE2E_MultiTenantSecurityViolation(t *testing.T) {
	server, fixtures := setupTestServer(t)
	defer server.Close()

	fixtures.MembershipRepo.UserInstitutions["usr_tenant_A"] = "inst_ALPHA"
	fixtures.MembershipRepo.ClubInstitutions["club_tenant_B"] = "inst_BETA"

	memID := "mem_tenant_err"
	usrID := "usr_tenant_A"
	clubID := "club_tenant_B"
	instID := "inst_ALPHA"
	newStat := "approved"
	oldStat := "pending"

	envelope := models.CloudEvent[models.DocumentEventData]{
		SpecVersion: "1.0",
		ID:          "tenant-violation-ce-1",
		Source:      "//firestore.googleapis.com",
		Type:        "google.cloud.firestore.document.v1.updated",
		Subject:     "documents/memberships/mem_tenant_err",
		Data: models.DocumentEventData{
			Value: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/memberships/mem_tenant_err",
				Fields: map[string]models.ValueHolder{
					"membership_id":  {StringValue: &memID},
					"user_id":        {StringValue: &usrID},
					"club_id":        {StringValue: &clubID},
					"institution_id": {StringValue: &instID},
					"status":         {StringValue: &newStat},
				},
			},
			OldValue: models.FirestoreDocument{
				Name: "projects/p/databases/(default)/documents/memberships/mem_tenant_err",
				Fields: map[string]models.ValueHolder{
					"status": {StringValue: &oldStat},
				},
			},
		},
	}
	bodyBytes, _ := json.Marshal(envelope)

	req, err := http.NewRequest(http.MethodPost, server.URL+"/events/membership", bytes.NewReader(bodyBytes))
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/cloudevents+json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected HTTP 403 Forbidden on multi-tenant violation, got %d", resp.StatusCode)
	}

	if len(fixtures.MembershipRepo.ExecutedBatches) != 0 {
		t.Errorf("expected 0 batch executions on tenant mismatch, got %d", len(fixtures.MembershipRepo.ExecutedBatches))
	}
}

func TestE2E_HealthCheck(t *testing.T) {
	server, _ := setupTestServer(t)
	defer server.Close()

	t.Run("GET /healthz returns 200 OK", func(t *testing.T) {
		resp, err := http.Get(server.URL + "/healthz")
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("expected status 200 OK, got %d", resp.StatusCode)
		}

		bodyBytes, _ := io.ReadAll(resp.Body)
		var healthResp map[string]string
		if err := json.Unmarshal(bodyBytes, &healthResp); err != nil {
			t.Fatalf("invalid json response: %v", err)
		}

		if healthResp["status"] != "ok" {
			t.Errorf("expected status 'ok', got '%s'", healthResp["status"])
		}
		if healthResp["timestamp"] == "" {
			t.Error("expected non-empty timestamp string in health check response")
		}
	})

	t.Run("POST /healthz returns 405 Method Not Allowed", func(t *testing.T) {
		resp, err := http.Post(server.URL+"/healthz", "application/json", nil)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusMethodNotAllowed {
			t.Errorf("expected status 405 Method Not Allowed, got %d", resp.StatusCode)
		}
	})
}
