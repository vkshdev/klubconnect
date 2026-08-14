package handlers

import (
	"context"
	"sync"
	"time"

	"firebase.google.com/go/v4/messaging"

	"klubconnect/backend/internal/models"
)

// DeviceToken represents a device token record retrieved from users/{userId}/devices.
type DeviceToken struct {
	ID        string    `firestore:"-" json:"id"`
	Token     string    `firestore:"token" json:"token"`
	DeviceID  string    `firestore:"device_id" json:"device_id"`
	Platform  string    `firestore:"platform" json:"platform"`
	UpdatedAt time.Time `firestore:"updated_at" json:"updated_at"`
}

// AuditRepository defines the interface for persisting audit records.
type AuditRepository interface {
	WriteAuditLog(ctx context.Context, record models.AuditLogRecord) error
}

// FCMClient defines the abstract interface for Firebase Cloud Messaging operations.
type FCMClient interface {
	SendEachForMulticast(ctx context.Context, message *messaging.MulticastMessage) (*messaging.BatchResponse, error)
}

// FirestoreRepository defines the abstract interface for notification and token data access.
type FirestoreRepository interface {
	GetUserDeviceTokens(ctx context.Context, userID string) ([]DeviceToken, error)
	DeleteDeviceToken(ctx context.Context, userID string, tokenID string) error
	UpdateNotificationStatus(ctx context.Context, notificationID string, status string, dispatchedAt time.Time, successCount, failureCount int, errMsg string) error
}

// MockAuditRepository is a thread-safe in-memory test double for AuditRepository.
type MockAuditRepository struct {
	mu          sync.Mutex
	Records     []models.AuditLogRecord
	FailWithErr error
}

// NewMockAuditRepository constructs a new MockAuditRepository.
func NewMockAuditRepository() *MockAuditRepository {
	return &MockAuditRepository{
		Records: make([]models.AuditLogRecord, 0),
	}
}

// WriteAuditLog appends an audit record to in-memory store or returns configured error.
func (m *MockAuditRepository) WriteAuditLog(ctx context.Context, record models.AuditLogRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.FailWithErr != nil {
		return m.FailWithErr
	}

	m.Records = append(m.Records, record)
	return nil
}

// GetRecords returns a thread-safe copy of recorded audit records.
func (m *MockAuditRepository) GetRecords() []models.AuditLogRecord {
	m.mu.Lock()
	defer m.mu.Unlock()

	result := make([]models.AuditLogRecord, len(m.Records))
	copy(result, m.Records)
	return result
}

// MockFCMClient is a thread-safe in-memory test double for FCMClient.
type MockFCMClient struct {
	mu           sync.Mutex
	SendFn       func(ctx context.Context, message *messaging.MulticastMessage) (*messaging.BatchResponse, error)
	SentMessages []*messaging.MulticastMessage
	FailWithErr  error
}

// NewMockFCMClient constructs a new MockFCMClient.
func NewMockFCMClient() *MockFCMClient {
	return &MockFCMClient{
		SentMessages: make([]*messaging.MulticastMessage, 0),
	}
}

// SendEachForMulticast records sent message and executes mock behavior.
func (m *MockFCMClient) SendEachForMulticast(ctx context.Context, message *messaging.MulticastMessage) (*messaging.BatchResponse, error) {
	m.mu.Lock()
	m.SentMessages = append(m.SentMessages, message)
	m.mu.Unlock()

	if m.SendFn != nil {
		return m.SendFn(ctx, message)
	}

	if m.FailWithErr != nil {
		return nil, m.FailWithErr
	}

	responses := make([]*messaging.SendResponse, len(message.Tokens))
	for i := range message.Tokens {
		responses[i] = &messaging.SendResponse{
			Success:   true,
			MessageID: "projects/klubconnect/messages/msg_mock",
		}
	}

	return &messaging.BatchResponse{
		SuccessCount: len(message.Tokens),
		FailureCount: 0,
		Responses:    responses,
	}, nil
}

// GetSentMessages returns a copy of recorded multicast messages.
func (m *MockFCMClient) GetSentMessages() []*messaging.MulticastMessage {
	m.mu.Lock()
	defer m.mu.Unlock()

	result := make([]*messaging.MulticastMessage, len(m.SentMessages))
	copy(result, m.SentMessages)
	return result
}

// MockFirestoreRepository is a thread-safe in-memory test double for FirestoreRepository.
type MockFirestoreRepository struct {
	mu                sync.Mutex
	Tokens            map[string][]DeviceToken
	DeletedTokens     []string
	UpdatedStatuses   map[string]string
	GetUserTokensErr  error
	DeleteTokenErr    error
	UpdateStatusErr   error
}

// NewMockFirestoreRepository constructs a new MockFirestoreRepository.
func NewMockFirestoreRepository() *MockFirestoreRepository {
	return &MockFirestoreRepository{
		Tokens:          make(map[string][]DeviceToken),
		DeletedTokens:   make([]string, 0),
		UpdatedStatuses: make(map[string]string),
	}
}

// GetUserDeviceTokens retrieves tokens for a user or returns configured error.
func (m *MockFirestoreRepository) GetUserDeviceTokens(ctx context.Context, userID string) ([]DeviceToken, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.GetUserTokensErr != nil {
		return nil, m.GetUserTokensErr
	}

	tokens, exists := m.Tokens[userID]
	if !exists {
		return []DeviceToken{}, nil
	}

	result := make([]DeviceToken, len(tokens))
	copy(result, tokens)
	return result, nil
}

// DeleteDeviceToken removes a token for a user or returns configured error.
func (m *MockFirestoreRepository) DeleteDeviceToken(ctx context.Context, userID string, tokenID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.DeleteTokenErr != nil {
		return m.DeleteTokenErr
	}

	m.DeletedTokens = append(m.DeletedTokens, tokenID)

	tokens, exists := m.Tokens[userID]
	if exists {
		filtered := make([]DeviceToken, 0, len(tokens))
		for _, t := range tokens {
			if t.ID != tokenID {
				filtered = append(filtered, t)
			}
		}
		m.Tokens[userID] = filtered
	}

	return nil
}

// UpdateNotificationStatus records notification status or returns configured error.
func (m *MockFirestoreRepository) UpdateNotificationStatus(ctx context.Context, notificationID string, status string, dispatchedAt time.Time, successCount, failureCount int, errMsg string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.UpdateStatusErr != nil {
		return m.UpdateStatusErr
	}

	m.UpdatedStatuses[notificationID] = status
	return nil
}
