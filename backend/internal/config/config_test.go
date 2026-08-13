package config_test

import (
	"context"
	"os"
	"testing"

	"klubconnect/backend/internal/config"
)

func TestLoad_Defaults(t *testing.T) {
	os.Unsetenv("PORT")
	os.Unsetenv("GCP_PROJECT_ID")
	os.Unsetenv("USE_SECRET_MANAGER")
	os.Unsetenv("FIRESTORE_STATE_COLLECTION")
	os.Unsetenv("FCM_SERVER_KEY")
	os.Unsetenv("APP_ENV")

	cfg, err := config.Load(context.Background())
	if err != nil {
		t.Fatalf("expected no error loading defaults, got %v", err)
	}

	if cfg.Port != "8080" {
		t.Errorf("expected default Port 8080, got %s", cfg.Port)
	}
	if cfg.GCPProjectID != "klubconnect-prod" {
		t.Errorf("expected default GCPProjectID klubconnect-prod, got %s", cfg.GCPProjectID)
	}
	if cfg.FirestoreStateCol != "go_worker_state" {
		t.Errorf("expected default FirestoreStateCol go_worker_state, got %s", cfg.FirestoreStateCol)
	}
	if cfg.WorkerStateCollection != "go_worker_state" {
		t.Errorf("expected default WorkerStateCollection go_worker_state, got %s", cfg.WorkerStateCollection)
	}
	if cfg.UseSecretManager != false {
		t.Errorf("expected default UseSecretManager false, got %v", cfg.UseSecretManager)
	}
	if cfg.Environment != "development" {
		t.Errorf("expected default Environment development, got %s", cfg.Environment)
	}
	if cfg.AuditLogsCollection != "audit_logs" {
		t.Errorf("expected default AuditLogsCollection audit_logs, got %s", cfg.AuditLogsCollection)
	}
}

func TestLoad_EnvOverrides(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("GCP_PROJECT_ID", "custom-gcp-project")
	t.Setenv("FIRESTORE_STATE_COLLECTION", "custom_state")
	t.Setenv("FCM_SERVER_KEY", "test-key-123")
	t.Setenv("APP_ENV", "production")
	t.Setenv("AUDIT_LOGS_COLLECTION", "custom_audit")
	t.Setenv("NOTIFICATIONS_COLLECTION", "custom_notif")

	cfg, err := config.Load(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if cfg.Port != "9090" {
		t.Errorf("expected Port 9090, got %s", cfg.Port)
	}
	if cfg.GCPProjectID != "custom-gcp-project" {
		t.Errorf("expected GCPProjectID custom-gcp-project, got %s", cfg.GCPProjectID)
	}
	if cfg.FirestoreStateCol != "custom_state" {
		t.Errorf("expected FirestoreStateCol custom_state, got %s", cfg.FirestoreStateCol)
	}
	if cfg.FCMServerKey != "test-key-123" {
		t.Errorf("expected FCMServerKey test-key-123, got %s", cfg.FCMServerKey)
	}
	if cfg.Environment != "production" {
		t.Errorf("expected Environment production, got %s", cfg.Environment)
	}
	if cfg.AuditLogsCollection != "custom_audit" {
		t.Errorf("expected AuditLogsCollection custom_audit, got %s", cfg.AuditLogsCollection)
	}
	if cfg.NotificationsCollection != "custom_notif" {
		t.Errorf("expected NotificationsCollection custom_notif, got %s", cfg.NotificationsCollection)
	}
}

func TestValidate_Invalid(t *testing.T) {
	cfg := &config.Config{
		Port:              "",
		GCPProjectID:      "klubconnect-prod",
		FirestoreStateCol: "go_worker_state",
	}

	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for empty Port, got nil")
	}

	cfg.Port = "invalid_port"
	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for non-numeric Port, got nil")
	}

	cfg.Port = "8080"
	cfg.GCPProjectID = ""
	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for empty GCPProjectID, got nil")
	}

	cfg.GCPProjectID = "klubconnect-prod"
	cfg.FirestoreStateCol = ""
	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for empty FirestoreStateCol, got nil")
	}
}

func TestConfig_SecretManagerFallback(t *testing.T) {
	t.Setenv("USE_SECRET_MANAGER", "true")
	t.Setenv("FCM_SERVER_KEY", "fallback-key-secret")

	// Secret Manager API will fail because no valid GCP credentials exist in test runner,
	// so it should fallback to local FCM_SERVER_KEY.
	cfg, err := config.Load(context.Background())
	if err != nil {
		t.Fatalf("expected fallback success, got error: %v", err)
	}

	if cfg.FCMServerKey != "fallback-key-secret" {
		t.Errorf("expected FCMServerKey 'fallback-key-secret', got '%s'", cfg.FCMServerKey)
	}
}

func TestValidate_PortBoundariesAndWhitespace(t *testing.T) {
	invalidPorts := []string{"0", "65536", "-10", "70000", "   "}
	for _, port := range invalidPorts {
		cfg := &config.Config{
			Port:              port,
			GCPProjectID:      "klubconnect-prod",
			FirestoreStateCol: "go_worker_state",
		}
		if err := cfg.Validate(); err == nil {
			t.Errorf("expected error for invalid Port '%s', got nil", port)
		}
	}

	// Test whitespace-only GCPProjectID and FirestoreStateCol
	cfg := &config.Config{
		Port:              "8080",
		GCPProjectID:      "   \t\n ",
		FirestoreStateCol: "go_worker_state",
	}
	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for whitespace GCPProjectID, got nil")
	}

	cfg.GCPProjectID = "klubconnect-prod"
	cfg.FirestoreStateCol = "   \t\n "
	if err := cfg.Validate(); err == nil {
		t.Errorf("expected error for whitespace FirestoreStateCol, got nil")
	}
}

