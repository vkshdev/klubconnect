package handlers

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/firestore"

	"klubconnect/backend/internal/idempotency"
)

var ErrTenantMismatch = errors.New("multi-tenant isolation violation: institution mismatch between user, club, and membership")

// MembershipApprovalBatchParams contains parameters for executing an atomic 4-collection membership approval write.
type MembershipApprovalBatchParams struct {
	MembershipID   string
	UserID         string
	ClubID         string
	InstitutionID  string
	ApprovedAt     time.Time
	NotificationID string
	WelcomeTitle   string
	WelcomeBody    string
}

// MembershipRepository defines the data access contract for membership approval operations.
type MembershipRepository interface {
	GetUserInstitution(ctx context.Context, userID string) (string, error)
	GetClubInstitution(ctx context.Context, clubID string) (string, error)
	ExecuteMembershipApprovalBatch(ctx context.Context, params MembershipApprovalBatchParams) error
}

// FirestoreMembershipRepository implements MembershipRepository using GCP Cloud Firestore.
type FirestoreMembershipRepository struct {
	client *firestore.Client
}

// NewFirestoreMembershipRepository constructs a new FirestoreMembershipRepository instance.
func NewFirestoreMembershipRepository(client *firestore.Client) *FirestoreMembershipRepository {
	return &FirestoreMembershipRepository{client: client}
}

// GetUserInstitution reads the user document and returns institution_id.
func (r *FirestoreMembershipRepository) GetUserInstitution(ctx context.Context, userID string) (string, error) {
	if r.client == nil {
		return "", errors.New("firestore client is nil")
	}

	docSnap, err := r.client.Collection("users").Doc(userID).Get(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to read user document %s: %w", userID, err)
	}

	val, err := docSnap.DataAt("institution_id")
	if err != nil {
		return "", fmt.Errorf("user document %s missing institution_id: %w", userID, err)
	}

	instID, ok := val.(string)
	if !ok {
		return "", fmt.Errorf("user document %s institution_id is not a string", userID)
	}

	return instID, nil
}

// GetClubInstitution reads the club document and returns institution_id.
func (r *FirestoreMembershipRepository) GetClubInstitution(ctx context.Context, clubID string) (string, error) {
	if r.client == nil {
		return "", errors.New("firestore client is nil")
	}

	docSnap, err := r.client.Collection("clubs").Doc(clubID).Get(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to read club document %s: %w", clubID, err)
	}

	val, err := docSnap.DataAt("institution_id")
	if err != nil {
		return "", fmt.Errorf("club document %s missing institution_id: %w", clubID, err)
	}

	instID, ok := val.(string)
	if !ok {
		return "", fmt.Errorf("club document %s institution_id is not a string", clubID)
	}

	return instID, nil
}

// ExecuteMembershipApprovalBatch commits an atomic batched write across 4 collections.
func (r *FirestoreMembershipRepository) ExecuteMembershipApprovalBatch(ctx context.Context, params MembershipApprovalBatchParams) error {
	if r.client == nil {
		return errors.New("firestore client is nil")
	}

	batch := r.client.Batch()

	memRef := r.client.Collection("memberships").Doc(params.MembershipID)
	batch.Update(memRef, []firestore.Update{
		{Path: "status", Value: "approved"},
		{Path: "approved_at", Value: params.ApprovedAt},
		{Path: "updated_at", Value: params.ApprovedAt},
	})

	userMemRef := r.client.Collection("user_memberships").Doc(params.UserID).Collection("clubs").Doc(params.ClubID)
	batch.Set(userMemRef, map[string]interface{}{
		"membership_id":  params.MembershipID,
		"club_id":        params.ClubID,
		"user_id":        params.UserID,
		"institution_id": params.InstitutionID,
		"status":         "active",
		"role":           "member",
		"joined_at":      params.ApprovedAt,
		"updated_at":     params.ApprovedAt,
	}, firestore.MergeAll)

	clubMemRef := r.client.Collection("clubs").Doc(params.ClubID).Collection("members").Doc(params.UserID)
	batch.Set(clubMemRef, map[string]interface{}{
		"membership_id":  params.MembershipID,
		"user_id":        params.UserID,
		"club_id":        params.ClubID,
		"institution_id": params.InstitutionID,
		"status":         "active",
		"role":           "member",
		"joined_at":      params.ApprovedAt,
		"updated_at":     params.ApprovedAt,
	}, firestore.MergeAll)

	notifRef := r.client.Collection("notifications").Doc(params.NotificationID)
	batch.Set(notifRef, map[string]interface{}{
		"notification_id": params.NotificationID,
		"user_id":         params.UserID,
		"club_id":         params.ClubID,
		"institution_id":  params.InstitutionID,
		"title":           params.WelcomeTitle,
		"body":            params.WelcomeBody,
		"type":            "membership_approval",
		"status":          "pending",
		"created_at":       params.ApprovedAt,
		"payload": map[string]string{
			"membership_id": params.MembershipID,
			"club_id":       params.ClubID,
		},
	})

	_, err := batch.Commit(ctx)
	if err != nil {
		return fmt.Errorf("failed to commit membership approval batch: %w", err)
	}

	return nil
}

// MembershipHandler handles CloudEvents for student membership approval state transitions.
type MembershipHandler struct {
	guard  idempotency.Guard
	repo   MembershipRepository
	logger *log.Logger
}

// NewMembershipHandler constructs a new MembershipHandler.
func NewMembershipHandler(guard idempotency.Guard, repo MembershipRepository) *MembershipHandler {
	return &MembershipHandler{
		guard:  guard,
		repo:   repo,
		logger: log.New(os.Stdout, "[MEMBERSHIP_HANDLER] ", log.LstdFlags|log.LUTC),
	}
}

// ServeHTTP handles HTTP POST requests for membership change events.
func (h *MembershipHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
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

	alreadyProcessed, err := h.guard.LockOrSkip(r.Context(), "membership_handler", parsed.ID)
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

	oldStatus := parsed.Data.OldValue.GetString("status")
	newStatus := parsed.Data.Value.GetString("status")

	if !(strings.EqualFold(oldStatus, "pending") && strings.EqualFold(newStatus, "approved")) {
		h.logger.Printf("[INFO] Event %s status transition not pending->approved (old: '%s', new: '%s'), skipping", parsed.ID, oldStatus, newStatus)
		if markErr := h.guard.MarkCompleted(r.Context(), "membership_handler", parsed.ID); markErr != nil {
			h.logger.Printf("[WARN] Failed to mark event completed: %v", markErr)
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"skipped","reason":"precondition_not_met"}`))
		return
	}

	membershipID := parsed.Data.Value.GetString("membership_id")
	if membershipID == "" {
		membershipID = parsed.Data.Value.GetString("request_id")
	}
	if membershipID == "" {
		membershipID = parsed.Data.Value.ExtractDocumentID()
	}
	if membershipID == "" {
		membershipID = parsed.Data.OldValue.ExtractDocumentID()
	}
	if membershipID == "" && parsed.Subject != "" {
		parts := strings.Split(strings.TrimPrefix(parsed.Subject, "/"), "/")
		if len(parts) > 0 {
			membershipID = parts[len(parts)-1]
		}
	}

	userID := parsed.Data.Value.GetString("user_id")
	if userID == "" {
		userID = parsed.Data.OldValue.GetString("user_id")
	}

	clubID := parsed.Data.Value.GetString("club_id")
	if clubID == "" {
		clubID = parsed.Data.OldValue.GetString("club_id")
	}

	membershipInstID := parsed.Data.Value.GetString("institution_id")
	if membershipInstID == "" {
		membershipInstID = parsed.Data.OldValue.GetString("institution_id")
	}

	if membershipID == "" || userID == "" || clubID == "" || membershipInstID == "" {
		h.logger.Printf("[ERROR] Missing required fields for event %s (membership_id: '%s', user_id: '%s', club_id: '%s', institution_id: '%s')",
			parsed.ID, membershipID, userID, clubID, membershipInstID)
		_ = h.guard.MarkFailed(r.Context(), "membership_handler", parsed.ID, errors.New("missing required fields"))
		http.Error(w, "missing required membership payload fields", http.StatusBadRequest)
		return
	}

	userInstID, err := h.repo.GetUserInstitution(r.Context(), userID)
	if err != nil {
		h.logger.Printf("[ERROR] Failed to fetch user institution for user %s: %v", userID, err)
		_ = h.guard.MarkFailed(r.Context(), "membership_handler", parsed.ID, err)
		http.Error(w, fmt.Sprintf("failed to verify user tenant: %v", err), http.StatusInternalServerError)
		return
	}

	clubInstID, err := h.repo.GetClubInstitution(r.Context(), clubID)
	if err != nil {
		h.logger.Printf("[ERROR] Failed to fetch club institution for club %s: %v", clubID, err)
		_ = h.guard.MarkFailed(r.Context(), "membership_handler", parsed.ID, err)
		http.Error(w, fmt.Sprintf("failed to verify club tenant: %v", err), http.StatusInternalServerError)
		return
	}

	if membershipInstID != userInstID || userInstID != clubInstID {
		h.logger.Printf("[ERROR] Multi-tenant isolation violation for membership %s: membership inst '%s', user inst '%s', club inst '%s'",
			membershipID, membershipInstID, userInstID, clubInstID)
		_ = h.guard.MarkFailed(r.Context(), "membership_handler", parsed.ID, ErrTenantMismatch)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusForbidden)
		w.Write([]byte(`{"error":"Forbidden: multi-tenant isolation violation"}`))
		return
	}

	now := time.Now().UTC()
	notifID := fmt.Sprintf("welcome_%s_%d", membershipID, now.UnixNano())
	params := MembershipApprovalBatchParams{
		MembershipID:   membershipID,
		UserID:         userID,
		ClubID:         clubID,
		InstitutionID:  membershipInstID,
		ApprovedAt:     now,
		NotificationID: notifID,
		WelcomeTitle:   "Membership Approved",
		WelcomeBody:    "Your membership request for the club has been approved! Welcome aboard.",
	}

	if err := h.repo.ExecuteMembershipApprovalBatch(r.Context(), params); err != nil {
		h.logger.Printf("[ERROR] Failed to execute membership approval batch for %s: %v", membershipID, err)
		_ = h.guard.MarkFailed(r.Context(), "membership_handler", parsed.ID, err)
		http.Error(w, fmt.Sprintf("batch write error: %v", err), http.StatusInternalServerError)
		return
	}

	if markErr := h.guard.MarkCompleted(r.Context(), "membership_handler", parsed.ID); markErr != nil {
		h.logger.Printf("[WARN] Failed to mark event completed: %v", markErr)
	}

	h.logger.Printf("[INFO] Successfully processed membership approval for %s (user: %s, club: %s)", membershipID, userID, clubID)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{"status":"success","membership_id":"%s"}`, membershipID)))
}
