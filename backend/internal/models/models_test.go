package models_test

import (
	"encoding/json"
	"testing"
	"time"

	"klubconnect/backend/internal/models"
)

func TestCloudEventParsing_StructuredJSON(t *testing.T) {
	rawJSON := `{
		"specversion": "1.0",
		"id": "evt-uuid-12345",
		"source": "//firestore.googleapis.com/projects/klubconnect-dev/databases/(default)",
		"type": "google.cloud.firestore.document.v1.updated",
		"subject": "documents/events/event999/rsvps/user888",
		"time": "2026-08-13T17:10:00Z",
		"data": {
			"value": {
				"name": "projects/klubconnect-dev/databases/(default)/documents/events/event999/rsvps/user888",
				"fields": {
					"status": { "stringValue": "going" },
					"updated_at": { "timestampValue": "2026-08-13T17:10:00Z" }
				}
			},
			"oldValue": {
				"name": "projects/klubconnect-dev/databases/(default)/documents/events/event999/rsvps/user888",
				"fields": {
					"status": { "stringValue": "interested" }
				}
			},
			"updateMask": {
				"fieldPaths": ["status", "updated_at"]
			}
		}
	}`

	var event models.CloudEvent[models.DocumentEventData]
	if err := json.Unmarshal([]byte(rawJSON), &event); err != nil {
		t.Fatalf("failed to unmarshal CloudEvent JSON: %v", err)
	}

	if event.ID != "evt-uuid-12345" {
		t.Errorf("expected ID 'evt-uuid-12345', got '%s'", event.ID)
	}
	if event.SpecVersion != "1.0" {
		t.Errorf("expected SpecVersion '1.0', got '%s'", event.SpecVersion)
	}
	if event.Data.Value.GetString("status") != "going" {
		t.Errorf("expected new status 'going', got '%s'", event.Data.Value.GetString("status"))
	}
	if event.Data.OldValue.GetString("status") != "interested" {
		t.Errorf("expected old status 'interested', got '%s'", event.Data.OldValue.GetString("status"))
	}
	if len(event.Data.UpdateMask.FieldPaths) != 2 {
		t.Errorf("expected 2 update mask field paths, got %d", len(event.Data.UpdateMask.FieldPaths))
	}
}

func TestValueHolder_Extractors(t *testing.T) {
	strVal := "hello"
	intStrVal := "105"
	doubleVal := 42.5
	boolVal := true
	timeStrVal := "2026-08-13T17:10:00Z"

	vhStr := models.ValueHolder{StringValue: &strVal}
	vhInt := models.ValueHolder{IntegerValue: &intStrVal}
	vhDouble := models.ValueHolder{DoubleValue: &doubleVal}
	vhBool := models.ValueHolder{BooleanValue: &boolVal}
	vhTime := models.ValueHolder{TimestampValue: &timeStrVal}
	vhEmpty := models.ValueHolder{}

	if vhStr.GetString() != "hello" {
		t.Errorf("expected 'hello', got '%s'", vhStr.GetString())
	}
	if vhInt.GetInt64() != 105 {
		t.Errorf("expected 105, got %d", vhInt.GetInt64())
	}
	if vhDouble.GetFloat64() != 42.5 {
		t.Errorf("expected 42.5, got %f", vhDouble.GetFloat64())
	}
	if !vhBool.GetBool() {
		t.Errorf("expected true, got false")
	}
	if vhTime.GetTimestamp().Format(time.RFC3339) != timeStrVal {
		t.Errorf("expected '%s', got '%s'", timeStrVal, vhTime.GetTimestamp().Format(time.RFC3339))
	}

	// Test zero defaults on empty ValueHolder
	if vhEmpty.GetString() != "" {
		t.Errorf("expected empty string, got '%s'", vhEmpty.GetString())
	}
	if vhEmpty.GetInt64() != 0 {
		t.Errorf("expected 0, got %d", vhEmpty.GetInt64())
	}
	if vhEmpty.GetFloat64() != 0.0 {
		t.Errorf("expected 0.0, got %f", vhEmpty.GetFloat64())
	}
	if vhEmpty.GetBool() != false {
		t.Errorf("expected false, got true")
	}
	if !vhEmpty.GetTimestamp().IsZero() {
		t.Errorf("expected zero time, got %v", vhEmpty.GetTimestamp())
	}
}

func TestValueHolder_GetStringArray(t *testing.T) {
	val1 := "admin"
	val2 := "member"
	vhArray := models.ValueHolder{
		ArrayValue: &models.ArrayValueHolder{
			Values: []models.ValueHolder{
				{StringValue: &val1},
				{StringValue: &val2},
			},
		},
	}

	arr := vhArray.GetStringArray()
	if len(arr) != 2 || arr[0] != "admin" || arr[1] != "member" {
		t.Errorf("expected ['admin', 'member'], got %v", arr)
	}

	var vhNilArr models.ValueHolder
	if vhNilArr.GetStringArray() != nil {
		t.Errorf("expected nil slice, got %v", vhNilArr.GetStringArray())
	}
}

func TestFirestoreDocument_Extractors(t *testing.T) {
	docName := "projects/klubconnect-dev/databases/(default)/documents/clubs/club777"
	title := "Computer Science Club"
	memberCountStr := "150"
	doubleVal := 99.9
	boolVal := true

	doc := &models.FirestoreDocument{
		Name: docName,
		Fields: map[string]models.ValueHolder{
			"title":        {StringValue: &title},
			"member_count": {IntegerValue: &memberCountStr},
			"score":        {DoubleValue: &doubleVal},
			"is_active":    {BooleanValue: &boolVal},
		},
	}

	if doc.ExtractDocumentID() != "club777" {
		t.Errorf("expected document ID 'club777', got '%s'", doc.ExtractDocumentID())
	}
	if doc.ExtractCollectionName() != "clubs" {
		t.Errorf("expected collection name 'clubs', got '%s'", doc.ExtractCollectionName())
	}
	if doc.GetString("title") != "Computer Science Club" {
		t.Errorf("expected 'Computer Science Club', got '%s'", doc.GetString("title"))
	}
	if doc.GetInt64("member_count") != 150 {
		t.Errorf("expected 150, got %d", doc.GetInt64("member_count"))
	}
	if doc.GetFloat64("score") != 99.9 {
		t.Errorf("expected 99.9, got %f", doc.GetFloat64("score"))
	}
	if !doc.GetBool("is_active") {
		t.Errorf("expected true, got false")
	}
	if doc.GetString("non_existent_key") != "" {
		t.Errorf("expected empty string for missing key, got '%s'", doc.GetString("non_existent_key"))
	}
}

func TestFirestoreDocument_GetMap(t *testing.T) {
	subKeyVal := "payload_val"
	doc := &models.FirestoreDocument{
		Fields: map[string]models.ValueHolder{
			"meta": {
				MapValue: &models.MapValueHolder{
					Fields: map[string]models.ValueHolder{
						"sub_key": {StringValue: &subKeyVal},
					},
				},
			},
		},
	}

	m := doc.GetMap("meta")
	if m == nil || m["sub_key"].GetString() != "payload_val" {
		t.Errorf("expected map with sub_key='payload_val', got %v", m)
	}

	if doc.GetMap("non_existent") != nil {
		t.Errorf("expected nil for missing map key")
	}
}

func TestNilDocumentSafety(t *testing.T) {
	var nilDoc *models.FirestoreDocument

	if nilDoc.GetString("key") != "" {
		t.Errorf("nil doc should return empty string")
	}
	if nilDoc.GetInt64("key") != 0 {
		t.Errorf("nil doc should return 0")
	}
	if nilDoc.GetFloat64("key") != 0.0 {
		t.Errorf("nil doc should return 0.0")
	}
	if nilDoc.GetBool("key") != false {
		t.Errorf("nil doc should return false")
	}
	if !nilDoc.GetTime("key").IsZero() {
		t.Errorf("nil doc should return zero time")
	}
	if nilDoc.GetStringArray("key") != nil {
		t.Errorf("nil doc should return nil slice")
	}
	if nilDoc.GetMap("key") != nil {
		t.Errorf("nil doc should return nil map")
	}
	if nilDoc.ExtractDocumentID() != "" {
		t.Errorf("nil doc should return empty document ID")
	}
	if nilDoc.ExtractCollectionName() != "" {
		t.Errorf("nil doc should return empty collection name")
	}
}

func TestValueHolder_EdgeCases(t *testing.T) {
	// 1. Invalid and overflowing integer strings
	invalidIntStr := "not_a_number"
	overflowIntStr := "99999999999999999999999999999999999999"
	vhInvalidInt := models.ValueHolder{IntegerValue: &invalidIntStr}
	vhOverflowInt := models.ValueHolder{IntegerValue: &overflowIntStr}

	if vhInvalidInt.GetInt64() != 0 {
		t.Errorf("expected 0 for invalid integer string, got %d", vhInvalidInt.GetInt64())
	}
	if vhOverflowInt.GetInt64() != 0 {
		t.Errorf("expected 0 for overflowing integer string, got %d", vhOverflowInt.GetInt64())
	}

	// 2. Malformed and Nano Timestamps
	invalidTimeStr := "invalid-timestamp"
	nanoTimeStr := "2026-08-13T17:10:00.123456789Z"
	vhInvalidTime := models.ValueHolder{TimestampValue: &invalidTimeStr}
	vhNanoTime := models.ValueHolder{TimestampValue: &nanoTimeStr}

	if !vhInvalidTime.GetTimestamp().IsZero() {
		t.Errorf("expected zero time for malformed timestamp string, got %v", vhInvalidTime.GetTimestamp())
	}
	if vhNanoTime.GetTimestamp().Format(time.RFC3339Nano) != nanoTimeStr {
		t.Errorf("expected '%s', got '%s'", nanoTimeStr, vhNanoTime.GetTimestamp().Format(time.RFC3339Nano))
	}

	// 3. Mixed type ArrayValue
	strVal := "valid_string"
	vhMixedArr := models.ValueHolder{
		ArrayValue: &models.ArrayValueHolder{
			Values: []models.ValueHolder{
				{IntegerValue: &invalidIntStr}, // No StringValue
				{StringValue: &strVal},
				{},                             // Empty ValueHolder
			},
		},
	}
	arr := vhMixedArr.GetStringArray()
	if len(arr) != 1 || arr[0] != "valid_string" {
		t.Errorf("expected ['valid_string'], got %v", arr)
	}
}

