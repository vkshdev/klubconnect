package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"firebase.google.com/go/v4/messaging"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

// FCMHandler processes CloudEvents for Firebase Cloud Messaging push notification dispatches.
type FCMHandler struct {
	guard     idempotency.Guard
	fcmClient FCMClient
	repo      FirestoreRepository
}

// NewFCMHandler constructs a new FCMHandler instance.
func NewFCMHandler(guard idempotency.Guard, fcmClient FCMClient, repo FirestoreRepository) *FCMHandler {
	return &FCMHandler{
		guard:     guard,
		fcmClient: fcmClient,
		repo:      repo,
	}
}

// ServeHTTP processes HTTP POST CloudEvent requests for FCM notification dispatch.
func (h *FCMHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	eventID, subject, docData, err := h.parseCloudEvent(r)
	if err != nil || eventID == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("invalid CloudEvent payload: %v", err),
		})
		return
	}

	ctx := r.Context()
	handlerName := "FCMHandler"

	alreadyProcessed, err := h.guard.LockOrSkip(ctx, handlerName, eventID)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("idempotency check failure: %v", err),
		})
		return
	}

	if alreadyProcessed {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":   "already_processed",
			"event_id": eventID,
		})
		return
	}

	doc := docData.Value
	if doc.Name == "" {
		doc = docData.OldValue
	}

	notificationID := doc.ExtractDocumentID()
	if notificationID == "" && subject != "" {
		parts := strings.Split(strings.TrimPrefix(subject, "/"), "/")
		if len(parts) > 0 {
			notificationID = parts[len(parts)-1]
		}
	}

	userID := doc.GetString("user_id")
	if userID == "" {
		userID = doc.GetString("recipient_id")
	}

	if notificationID == "" || userID == "" {
		_ = h.guard.MarkFailed(ctx, handlerName, eventID, errors.New("missing notification_id or user_id"))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": "missing required notification_id or user_id",
		})
		return
	}

	tokens, err := h.repo.GetUserDeviceTokens(ctx, userID)
	if err != nil {
		_ = h.guard.MarkFailed(ctx, handlerName, eventID, err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("failed to fetch device tokens: %v", err),
		})
		return
	}

	if len(tokens) == 0 {
		_ = h.repo.UpdateNotificationStatus(ctx, notificationID, "skipped", time.Now().UTC(), 0, 0, "No device tokens registered for user")
		_ = h.guard.MarkCompleted(ctx, handlerName, eventID)

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":          "skipped",
			"reason":          "no_active_device_tokens",
			"notification_id": notificationID,
		})
		return
	}

	tokenStrings := make([]string, len(tokens))
	for i, t := range tokens {
		tokenStrings[i] = t.Token
	}

	title := doc.GetString("title")
	body := doc.GetString("body")
	notifType := doc.GetString("type")
	rawPayload := doc.GetMap("payload")

	fcmData := map[string]string{
		"notification_id": notificationID,
		"type":            notifType,
	}
	for k, vh := range rawPayload {
		if strVal := vh.GetString(); strVal != "" {
			fcmData[k] = strVal
		}
	}

	multicastMsg := &messaging.MulticastMessage{
		Tokens: tokenStrings,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: fcmData,
	}

	batchResp, err := h.fcmClient.SendEachForMulticast(ctx, multicastMsg)
	if err != nil {
		_ = h.repo.UpdateNotificationStatus(ctx, notificationID, "failed", time.Now().UTC(), 0, len(tokens), err.Error())
		_ = h.guard.MarkFailed(ctx, handlerName, eventID, err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("FCM multicast error: %v", err),
		})
		return
	}

	var prunedCount int
	if batchResp != nil && len(batchResp.Responses) > 0 {
		for i, sendResp := range batchResp.Responses {
			if sendResp != nil && !sendResp.Success && sendResp.Error != nil {
				if isStaleTokenError(sendResp.Error) {
					tokenID := tokens[i].ID
					if delErr := h.repo.DeleteDeviceToken(ctx, userID, tokenID); delErr == nil {
						prunedCount++
					}
				}
			}
		}
	}

	finalStatus := "dispatched"
	successCount := 0
	failureCount := 0
	if batchResp != nil {
		successCount = batchResp.SuccessCount
		failureCount = batchResp.FailureCount
		if successCount == 0 && failureCount > 0 {
			finalStatus = "failed"
		}
	}

	_ = h.repo.UpdateNotificationStatus(ctx, notificationID, finalStatus, time.Now().UTC(), successCount, failureCount, "")
	_ = h.guard.MarkCompleted(ctx, handlerName, eventID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status":          finalStatus,
		"notification_id": notificationID,
		"success_count":   successCount,
		"failure_count":   failureCount,
		"pruned_tokens":   prunedCount,
	})
}

// parseCloudEvent parses Binary or Structured CloudEvent payload.
func (h *FCMHandler) parseCloudEvent(r *http.Request) (string, string, models.DocumentEventData, error) {
	var docData models.DocumentEventData

	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		return "", "", docData, fmt.Errorf("failed to read body: %w", err)
	}

	ceID := r.Header.Get("ce-id")
	if ceID == "" {
		ceID = r.Header.Get("CloudEvents-ID")
	}
	if ceID == "" {
		ceID = r.Header.Get("CloudEvent-ID")
	}

	if ceID != "" {
		subject := r.Header.Get("ce-subject")
		if subject == "" {
			subject = r.Header.Get("CloudEvents-Subject")
		}
		if subject == "" {
			subject = r.Header.Get("CloudEvent-Subject")
		}

		if len(bodyBytes) > 0 {
			if unmarshalErr := json.Unmarshal(bodyBytes, &docData); unmarshalErr != nil {
				return "", "", docData, fmt.Errorf("invalid binary JSON body: %w", unmarshalErr)
			}
		}
		return ceID, subject, docData, nil
	}

	var envelope struct {
		ID      string                   `json:"id"`
		Subject string                   `json:"subject"`
		Data    models.DocumentEventData `json:"data"`
	}
	if len(bodyBytes) > 0 {
		if unmarshalErr := json.Unmarshal(bodyBytes, &envelope); unmarshalErr == nil && envelope.ID != "" {
			return envelope.ID, envelope.Subject, envelope.Data, nil
		}
	}

	return "", "", docData, errors.New("missing CloudEvent ID or invalid payload format")
}

// isStaleTokenError determines if an FCM send response error indicates a stale/invalid token.
func isStaleTokenError(err error) bool {
	if err == nil {
		return false
	}
	if messaging.IsUnregistered(err) || messaging.IsInvalidArgument(err) {
		return true
	}
	errMsg := err.Error()
	return strings.Contains(errMsg, "Unregistered") ||
		strings.Contains(errMsg, "InvalidArgument") ||
		strings.Contains(errMsg, "registration-token-not-registered") ||
		strings.Contains(errMsg, "invalid-registration-token")
}
