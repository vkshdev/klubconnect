package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

// AuditHandler processes CloudEvents for audit log recording.
type AuditHandler struct {
	guard idempotency.Guard
	repo  AuditRepository
}

// NewAuditHandler constructs a new AuditHandler instance.
func NewAuditHandler(guard idempotency.Guard, repo AuditRepository) *AuditHandler {
	return &AuditHandler{
		guard: guard,
		repo:  repo,
	}
}

// ServeHTTP handles HTTP requests for audit event processing.
func (h *AuditHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
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
	handlerName := "AuditHandler"

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
		w.WriteHeader(http.StatusAlreadyReported)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":   "already_processed",
			"event_id": eventID,
		})
		return
	}

	auditRecord := h.extractAuditRecord(eventID, subject, docData)

	if writeErr := h.repo.WriteAuditLog(ctx, auditRecord); writeErr != nil {
		_ = h.guard.MarkFailed(ctx, handlerName, eventID, writeErr)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("failed to write audit record: %v", writeErr),
		})
		return
	}

	if markErr := h.guard.MarkCompleted(ctx, handlerName, eventID); markErr != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("failed to update idempotency status: %v", markErr),
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status":   "success",
		"audit_id": auditRecord.AuditID,
		"event_id": eventID,
	})
}

// parseCloudEvent parses Binary or Structured CloudEvent requests into CloudEvent ID, Subject, and DocumentEventData.
func (h *AuditHandler) parseCloudEvent(r *http.Request) (string, string, models.DocumentEventData, error) {
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

// extractAuditRecord builds AuditLogRecord from DocumentEventData payload.
func (h *AuditHandler) extractAuditRecord(eventID, subject string, docData models.DocumentEventData) models.AuditLogRecord {
	var targetDocID string
	var targetCol string
	var action string
	var actorID string
	var changedFields []string

	doc := docData.Value
	if doc.Name == "" {
		doc = docData.OldValue
	}

	if doc.Name != "" {
		targetDocID = doc.ExtractDocumentID()
		targetCol = doc.ExtractCollectionName()
	} else if subject != "" {
		parts := strings.Split(strings.TrimPrefix(subject, "/"), "/")
		if len(parts) >= 2 {
			targetDocID = parts[len(parts)-1]
			targetCol = parts[len(parts)-2]
		}
	}

	if docData.Value.Name != "" && docData.OldValue.Name == "" {
		action = "CREATE"
	} else if docData.Value.Name != "" && docData.OldValue.Name != "" {
		action = "UPDATE"
	} else if docData.Value.Name == "" && docData.OldValue.Name != "" {
		action = "DELETE"
	} else {
		action = "UPDATE"
	}

	actorID = docData.Value.GetString("actor_user_id")
	if actorID == "" {
		actorID = docData.Value.GetString("updated_by")
	}
	if actorID == "" {
		actorID = docData.Value.GetString("created_by")
	}
	if actorID == "" {
		actorID = docData.Value.GetString("user_id")
	}
	if actorID == "" {
		actorID = docData.OldValue.GetString("actor_user_id")
	}
	if actorID == "" {
		actorID = docData.OldValue.GetString("updated_by")
	}
	if actorID == "" {
		actorID = docData.OldValue.GetString("created_by")
	}
	if actorID == "" {
		actorID = docData.OldValue.GetString("user_id")
	}
	if actorID == "" {
		actorID = "system"
	}

	if action == "UPDATE" && len(docData.UpdateMask.FieldPaths) > 0 {
		changedFields = docData.UpdateMask.FieldPaths
	} else if action == "CREATE" && docData.Value.Fields != nil {
		for k := range docData.Value.Fields {
			changedFields = append(changedFields, k)
		}
	} else if action == "DELETE" && docData.OldValue.Fields != nil {
		for k := range docData.OldValue.Fields {
			changedFields = append(changedFields, k)
		}
	}

	if len(changedFields) == 0 {
		changedFields = []string{"*"}
	}

	auditID := fmt.Sprintf("audit_%s_%d", eventID, time.Now().UnixNano())

	return models.AuditLogRecord{
		AuditID:          auditID,
		CloudEventID:     eventID,
		ActorID:          actorID,
		TargetCollection: targetCol,
		TargetDocumentID: targetDocID,
		Action:           action,
		Timestamp:        time.Now().UTC(),
		ChangedFields:    changedFields,
	}
}
