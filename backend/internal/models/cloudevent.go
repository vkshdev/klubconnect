package models

import (
	"strconv"
	"strings"
	"time"
)

// CloudEvent represents a generic CloudEvent v1.0 wrapper envelope.
type CloudEvent[T any] struct {
	SpecVersion string    `json:"specversion"`
	ID          string    `json:"id"`
	Source      string    `json:"source"`
	Type        string    `json:"type"`
	Subject     string    `json:"subject,omitempty"`
	Time        time.Time `json:"time,omitempty"`
	Data        T         `json:"data"`
}

// DocumentEventData represents the payload delivered in CloudEvent data for Firestore triggers.
type DocumentEventData struct {
	Value      FirestoreDocument `json:"value,omitempty"`
	OldValue   FirestoreDocument `json:"oldValue,omitempty"`
	UpdateMask UpdateMask        `json:"updateMask,omitempty"`
}

// FirestoreDocument represents the proto JSON format of a Firestore document.
type FirestoreDocument struct {
	Name       string                 `json:"name"`
	Fields     map[string]ValueHolder `json:"fields"`
	CreateTime time.Time              `json:"createTime"`
	UpdateTime time.Time              `json:"updateTime"`
}

// UpdateMask contains field names changed during an update operation.
type UpdateMask struct {
	FieldPaths []string `json:"fieldPaths,omitempty"`
}

// ValueHolder represents a typed Firestore Value container as formatted in proto JSON.
type ValueHolder struct {
	StringValue    *string           `json:"stringValue,omitempty"`
	IntegerValue   *string           `json:"integerValue,omitempty"`
	DoubleValue    *float64          `json:"doubleValue,omitempty"`
	BooleanValue   *bool             `json:"booleanValue,omitempty"`
	TimestampValue *string           `json:"timestampValue,omitempty"`
	ArrayValue     *ArrayValueHolder `json:"arrayValue,omitempty"`
	MapValue       *MapValueHolder   `json:"mapValue,omitempty"`
	ReferenceValue *string           `json:"referenceValue,omitempty"`
}

// ArrayValueHolder holds array elements in Firestore proto JSON.
type ArrayValueHolder struct {
	Values []ValueHolder `json:"values,omitempty"`
}

// MapValueHolder holds nested object fields in Firestore proto JSON.
type MapValueHolder struct {
	Fields map[string]ValueHolder `json:"fields,omitempty"`
}

// GetString returns string value or empty string if not present.
func (v ValueHolder) GetString() string {
	if v.StringValue != nil {
		return *v.StringValue
	}
	return ""
}

// GetInt64 returns parsed int64 or 0 if missing or invalid.
func (v ValueHolder) GetInt64() int64 {
	if v.IntegerValue != nil {
		val, err := strconv.ParseInt(*v.IntegerValue, 10, 64)
		if err == nil {
			return val
		}
	}
	return 0
}

// GetFloat64 returns float64 value or 0.0 if missing.
func (v ValueHolder) GetFloat64() float64 {
	if v.DoubleValue != nil {
		return *v.DoubleValue
	}
	return 0.0
}

// GetBool returns boolean value or false if missing.
func (v ValueHolder) GetBool() bool {
	if v.BooleanValue != nil {
		return *v.BooleanValue
	}
	return false
}

// GetTimestamp returns time.Time parsed from RFC3339 timestamp string or zero time.
func (v ValueHolder) GetTimestamp() time.Time {
	if v.TimestampValue != nil {
		t, err := time.Parse(time.RFC3339Nano, *v.TimestampValue)
		if err == nil {
			return t
		}
		t, err = time.Parse(time.RFC3339, *v.TimestampValue)
		if err == nil {
			return t
		}
	}
	return time.Time{}
}

// GetStringArray returns slice of strings extracted from arrayValue.
func (v ValueHolder) GetStringArray() []string {
	if v.ArrayValue == nil || len(v.ArrayValue.Values) == 0 {
		return nil
	}
	result := make([]string, 0, len(v.ArrayValue.Values))
	for _, item := range v.ArrayValue.Values {
		if item.StringValue != nil {
			result = append(result, *item.StringValue)
		}
	}
	return result
}

// GetString gets string value for a given field key.
func (doc *FirestoreDocument) GetString(key string) string {
	if doc == nil || doc.Fields == nil {
		return ""
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetString()
	}
	return ""
}

// GetInt64 gets int64 value for a given field key.
func (doc *FirestoreDocument) GetInt64(key string) int64 {
	if doc == nil || doc.Fields == nil {
		return 0
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetInt64()
	}
	return 0
}

// GetFloat64 gets float64 value for a given field key.
func (doc *FirestoreDocument) GetFloat64(key string) float64 {
	if doc == nil || doc.Fields == nil {
		return 0.0
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetFloat64()
	}
	return 0.0
}

// GetBool gets bool value for a given field key.
func (doc *FirestoreDocument) GetBool(key string) bool {
	if doc == nil || doc.Fields == nil {
		return false
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetBool()
	}
	return false
}

// GetTime gets time.Time for a given field key.
func (doc *FirestoreDocument) GetTime(key string) time.Time {
	if doc == nil || doc.Fields == nil {
		return time.Time{}
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetTimestamp()
	}
	return time.Time{}
}

// GetStringArray gets string slice for a given field key.
func (doc *FirestoreDocument) GetStringArray(key string) []string {
	if doc == nil || doc.Fields == nil {
		return nil
	}
	if val, ok := doc.Fields[key]; ok {
		return val.GetStringArray()
	}
	return nil
}

// GetMap gets map[string]ValueHolder for a given field key.
func (doc *FirestoreDocument) GetMap(key string) map[string]ValueHolder {
	if doc == nil || doc.Fields == nil {
		return nil
	}
	if val, ok := doc.Fields[key]; ok && val.MapValue != nil {
		return val.MapValue.Fields
	}
	return nil
}

// ExtractDocumentID extracts the relative document ID from doc.Name.
func (doc *FirestoreDocument) ExtractDocumentID() string {
	if doc == nil || doc.Name == "" {
		return ""
	}
	parts := strings.Split(doc.Name, "/")
	return parts[len(parts)-1]
}

// ExtractCollectionName extracts the target collection name from doc.Name.
func (doc *FirestoreDocument) ExtractCollectionName() string {
	if doc == nil || doc.Name == "" {
		return ""
	}
	parts := strings.Split(doc.Name, "/")
	if len(parts) >= 2 {
		return parts[len(parts)-2]
	}
	return ""
}

// AuditLogRecord represents a structured entry written to the audit_logs collection.
type AuditLogRecord struct {
	AuditID          string    `firestore:"audit_id" json:"audit_id"`
	CloudEventID     string    `firestore:"cloud_event_id" json:"cloud_event_id"`
	ActorID          string    `firestore:"actor_id" json:"actor_id"`
	TargetCollection string    `firestore:"target_collection" json:"target_collection"`
	TargetDocumentID string    `firestore:"target_document_id" json:"target_document_id"`
	Action           string    `firestore:"action" json:"action"`
	Timestamp        time.Time `firestore:"timestamp" json:"timestamp"`
	ChangedFields    []string  `firestore:"changed_fields" json:"changed_fields"`
}

// FCMNotificationData represents parsed notification payload from notifications collection.
type FCMNotificationData struct {
	NotificationID string            `json:"notification_id"`
	UserID         string            `json:"user_id"`
	Title          string            `json:"title"`
	Body           string            `json:"body"`
	Type           string            `json:"type"`
	Payload        map[string]string `json:"payload,omitempty"`
	Status         string            `json:"status"`
	CreatedAt      time.Time         `json:"created_at"`
}

// RSVPData represents parsed RSVP record from events/{eventId}/rsvps/{userId}.
type RSVPData struct {
	EventID        string    `json:"event_id"`
	UserID         string    `json:"user_id"`
	Status         string    `json:"status"` // "going", "interested", "not_going"
	PreviousStatus string    `json:"previous_status,omitempty"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// MembershipRequestData represents parsed membership request update.
type MembershipRequestData struct {
	RequestID      string    `json:"request_id"`
	ClubID         string    `json:"club_id"`
	UserID         string    `json:"user_id"`
	Status         string    `json:"status"` // "pending", "approved", "rejected"
	PreviousStatus string    `json:"previous_status,omitempty"`
	UpdatedAt      time.Time `json:"updated_at"`
}
