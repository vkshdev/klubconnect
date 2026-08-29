package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"

	"klubconnect/backend/internal/config"
	"klubconnect/backend/internal/handlers"
	"klubconnect/backend/internal/idempotency"
	"klubconnect/backend/internal/models"
)

// FirestoreAuditRepository implements handlers.AuditRepository using Cloud Firestore.
type FirestoreAuditRepository struct {
	client         *firestore.Client
	collectionName string
}

// NewFirestoreAuditRepository creates a new FirestoreAuditRepository.
func NewFirestoreAuditRepository(client *firestore.Client, collectionName string) *FirestoreAuditRepository {
	if collectionName == "" {
		collectionName = "audit_logs"
	}
	return &FirestoreAuditRepository{
		client:         client,
		collectionName: collectionName,
	}
}

// WriteAuditLog writes an audit log record into Firestore.
func (r *FirestoreAuditRepository) WriteAuditLog(ctx context.Context, record models.AuditLogRecord) error {
	if r.client == nil {
		return errors.New("firestore client is nil")
	}
	_, err := r.client.Collection(r.collectionName).Doc(record.AuditID).Set(ctx, record)
	return err
}

// FirestoreNotificationRepository implements handlers.FirestoreRepository using Cloud Firestore.
type FirestoreNotificationRepository struct {
	client                  *firestore.Client
	notificationsCollection string
}

// NewFirestoreNotificationRepository creates a new FirestoreNotificationRepository.
func NewFirestoreNotificationRepository(client *firestore.Client, notificationsCollection string) *FirestoreNotificationRepository {
	if notificationsCollection == "" {
		notificationsCollection = "notifications"
	}
	return &FirestoreNotificationRepository{
		client:                  client,
		notificationsCollection: notificationsCollection,
	}
}

// GetUserDeviceTokens fetches device tokens for a user from users/{userID}/devices collection.
func (r *FirestoreNotificationRepository) GetUserDeviceTokens(ctx context.Context, userID string) ([]handlers.DeviceToken, error) {
	if r.client == nil {
		return nil, errors.New("firestore client is nil")
	}
	snaps, err := r.client.Collection("users").Doc(userID).Collection("devices").Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	tokens := make([]handlers.DeviceToken, 0, len(snaps))
	for _, snap := range snaps {
		var t handlers.DeviceToken
		if err := snap.DataTo(&t); err == nil {
			t.ID = snap.Ref.ID
			tokens = append(tokens, t)
		}
	}
	return tokens, nil
}

// DeleteDeviceToken deletes a device token from users/{userID}/devices/{tokenID}.
func (r *FirestoreNotificationRepository) DeleteDeviceToken(ctx context.Context, userID string, tokenID string) error {
	if r.client == nil {
		return errors.New("firestore client is nil")
	}
	_, err := r.client.Collection("users").Doc(userID).Collection("devices").Doc(tokenID).Delete(ctx)
	return err
}

// UpdateNotificationStatus updates status of a notification document.
func (r *FirestoreNotificationRepository) UpdateNotificationStatus(ctx context.Context, notificationID string, status string, dispatchedAt time.Time, successCount, failureCount int, errMsg string) error {
	if r.client == nil {
		return errors.New("firestore client is nil")
	}
	updates := []firestore.Update{
		{Path: "status", Value: status},
		{Path: "dispatched_at", Value: dispatchedAt},
		{Path: "success_count", Value: successCount},
		{Path: "failure_count", Value: failureCount},
		{Path: "error_message", Value: errMsg},
		{Path: "updated_at", Value: dispatchedAt},
	}
	_, err := r.client.Collection(r.notificationsCollection).Doc(notificationID).Update(ctx, updates)
	return err
}

// MockRSVPRepository is an in-memory test double for RSVPRepository.
type MockRSVPRepository struct {
	mu            sync.Mutex
	Counters      map[string]map[string]int64
	ShouldFailErr error
}

// NewMockRSVPRepository creates a new MockRSVPRepository instance.
func NewMockRSVPRepository() *MockRSVPRepository {
	return &MockRSVPRepository{
		Counters: make(map[string]map[string]int64),
	}
}

// UpdateEventCounters updates event counters in-memory.
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

// MockMembershipRepository is an in-memory test double for MembershipRepository.
type MockMembershipRepository struct {
	mu               sync.Mutex
	UserInstitutions map[string]string
	ClubInstitutions map[string]string
	UserErr          error
	ClubErr          error
	BatchErr         error
	ExecutedBatches  []handlers.MembershipApprovalBatchParams
}

// NewMockMembershipRepository creates a new MockMembershipRepository instance.
func NewMockMembershipRepository() *MockMembershipRepository {
	return &MockMembershipRepository{
		UserInstitutions: make(map[string]string),
		ClubInstitutions: make(map[string]string),
	}
}

// GetUserInstitution retrieves the institution ID for a user.
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

// GetClubInstitution retrieves the institution ID for a club.
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

// ExecuteMembershipApprovalBatch records a membership approval batch in-memory.
func (m *MockMembershipRepository) ExecuteMembershipApprovalBatch(ctx context.Context, params handlers.MembershipApprovalBatchParams) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.BatchErr != nil {
		return m.BatchErr
	}
	m.ExecutedBatches = append(m.ExecutedBatches, params)
	return nil
}

// responseWriterWrapper wraps ResponseWriter to capture HTTP status code for logging.
type responseWriterWrapper struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriterWrapper) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriterWrapper{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rw, r)
		log.Printf("[HTTP] %s %s %d %s", r.Method, r.URL.Path, rw.statusCode, time.Since(start))
	})
}

func recoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				log.Printf("[PANIC RECOVERY] %v", err)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusInternalServerError)
				_ = json.NewEncoder(w).Encode(map[string]string{
					"error": "Internal Server Error",
				})
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		next.ServeHTTP(w, r)
	})
}

func bodyLimitMiddleware(maxBytes int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
			next.ServeHTTP(w, r)
		})
	}
}

func authMiddleware(expectedSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if expectedSecret == "" {
				next.ServeHTTP(w, r)
				return
			}

			authHeader := r.Header.Get("Authorization")
			eventarcSecret := r.Header.Get("X-CloudEvent-Secret")

			if eventarcSecret == expectedSecret || authHeader == "Bearer "+expectedSecret {
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"error": "Unauthorized: invalid or missing authentication token",
			})
		})
	}
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", http.MethodGet)
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status":    "ok",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// BuildRouter configures HTTP routes for all 4 CloudEvent handlers and the health check endpoint.
func BuildRouter(
	guard idempotency.Guard,
	auditRepo handlers.AuditRepository,
	fcmClient handlers.FCMClient,
	fcmRepo handlers.FirestoreRepository,
	rsvpRepo handlers.RSVPRepository,
	membershipRepo handlers.MembershipRepository,
) http.Handler {
	mux := http.NewServeMux()

	webhookSecret := os.Getenv("EVENTARC_SECRET")
	authWrap := authMiddleware(webhookSecret)

	auditHandler := handlers.NewAuditHandler(guard, auditRepo)
	fcmHandler := handlers.NewFCMHandler(guard, fcmClient, fcmRepo)
	rsvpHandler := handlers.NewRSVPHandler(guard, rsvpRepo)
	membershipHandler := handlers.NewMembershipHandler(guard, membershipRepo)

	mux.Handle("/events/audit", authWrap(auditHandler))
	mux.Handle("/events/fcm", authWrap(fcmHandler))
	mux.Handle("/events/rsvp", authWrap(rsvpHandler))
	mux.Handle("/events/membership", authWrap(membershipHandler))
	mux.HandleFunc("/healthz", healthzHandler)

	limitWrap := bodyLimitMiddleware(2 << 20) // 2MB max payload limit
	return recoveryMiddleware(loggingMiddleware(securityHeadersMiddleware(limitWrap(mux))))
}

func main() {
	log.Println("[INIT] Starting KlubConnect Go Backend Microservice Worker...")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg, err := config.Load(ctx)
	if err != nil {
		log.Fatalf("[FATAL] Configuration load error: %v", err)
	}

	log.Printf("[CONFIG] Environment: %s, Port: %s, GCP Project ID: %s", cfg.Environment, cfg.Port, cfg.GCPProjectID)

	var (
		guard          idempotency.Guard
		auditRepo      handlers.AuditRepository
		fcmClient      handlers.FCMClient
		fcmRepo        handlers.FirestoreRepository
		rsvpRepo       handlers.RSVPRepository
		membershipRepo handlers.MembershipRepository
	)

	if cfg.Environment == "test" || cfg.Environment == "development" {
		log.Println("[MODE] Initializing in-memory guards and repository mocks for local environment...")
		guard = idempotency.NewMemoryGuard()
		auditRepo = handlers.NewMockAuditRepository()
		fcmClient = handlers.NewMockFCMClient()
		fcmRepo = handlers.NewMockFirestoreRepository()
		rsvpRepo = NewMockRSVPRepository()
		membershipRepo = NewMockMembershipRepository()
	} else {
		log.Println("[MODE] Initializing GCP Firestore and Firebase Cloud Messaging clients...")
		firestoreClient, err := firestore.NewClient(ctx, cfg.GCPProjectID)
		if err != nil {
			log.Fatalf("[FATAL] Failed to initialize Firestore client: %v", err)
		}
		defer firestoreClient.Close()

		guard = idempotency.NewFirestoreGuard(firestoreClient, cfg.FirestoreStateCol)
		auditRepo = NewFirestoreAuditRepository(firestoreClient, cfg.AuditLogsCollection)
		fcmRepo = NewFirestoreNotificationRepository(firestoreClient, cfg.NotificationsCollection)
		rsvpRepo = handlers.NewFirestoreRSVPRepository(firestoreClient)
		membershipRepo = handlers.NewFirestoreMembershipRepository(firestoreClient)

		fbApp, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: cfg.GCPProjectID})
		if err != nil {
			log.Fatalf("[FATAL] Failed to initialize Firebase App: %v", err)
		}
		msgClient, err := fbApp.Messaging(ctx)
		if err != nil {
			log.Fatalf("[FATAL] Failed to initialize Firebase Messaging client: %v", err)
		}
		fcmClient = msgClient
	}

	router := BuildRouter(guard, auditRepo, fcmClient, fcmRepo, rsvpRepo, membershipRepo)

	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		log.Printf("[SERVER] Listening and serving HTTP on port %s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrors <- err
		}
	}()

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		log.Fatalf("[FATAL] Server HTTP listener failure: %v", err)
	case sig := <-shutdown:
		log.Printf("[SHUTDOWN] Received signal '%v'. Initiating graceful shutdown...", sig)

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("[ERROR] Server graceful shutdown timeout error: %v", err)
			_ = server.Close()
		} else {
			log.Println("[SHUTDOWN] HTTP Server stopped gracefully.")
		}
	}
}
