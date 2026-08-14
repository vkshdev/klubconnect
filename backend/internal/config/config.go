package config

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	secretmanagerpb "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

// Config holds runtime configuration settings for the backend worker.
type Config struct {
	Port                    string `json:"port"`
	Environment             string `json:"environment"`
	GCPProjectID            string `json:"gcp_project_id"`
	WorkerStateCollection   string `json:"worker_state_collection"`
	FirestoreStateCol       string `json:"firestore_state_col"`
	AuditLogsCollection     string `json:"audit_logs_collection"`
	NotificationsCollection string `json:"notifications_collection"`
	RSVPCountersCollection  string `json:"rsvp_counters_collection"`
	MembershipsCollection   string `json:"memberships_collection"`
	UseSecretManager        bool   `json:"use_secret_manager"`
	FCMServerKeySecretName  string `json:"fcm_server_key_secret_name"`
	FCMServerKey            string `json:"fcm_server_key"`
}

// Load reads configuration from environment variables and GCP Secret Manager.
func Load(ctx context.Context) (*Config, error) {
	stateCol := getEnvOrDefault("FIRESTORE_STATE_COLLECTION", getEnvOrDefault("FIRESTORE_WORKER_STATE_COLLECTION", "go_worker_state"))
	secretName := getEnvOrDefault("FCM_SECRET_NAME", getEnvOrDefault("FCM_SERVER_KEY_SECRET_NAME", "fcm-server-key"))

	cfg := &Config{
		Port:                    getEnvOrDefault("PORT", "8080"),
		Environment:             getEnvOrDefault("APP_ENV", getEnvOrDefault("ENVIRONMENT", "development")),
		GCPProjectID:            getEnvOrDefault("GCP_PROJECT_ID", "klubconnect-prod"),
		WorkerStateCollection:   stateCol,
		FirestoreStateCol:       stateCol,
		AuditLogsCollection:     getEnvOrDefault("AUDIT_LOGS_COLLECTION", getEnvOrDefault("FIRESTORE_AUDIT_LOGS_COLLECTION", "audit_logs")),
		NotificationsCollection: getEnvOrDefault("NOTIFICATIONS_COLLECTION", getEnvOrDefault("FIRESTORE_NOTIFICATIONS_COLLECTION", "notifications")),
		RSVPCountersCollection:  getEnvOrDefault("RSVP_COUNTERS_COLLECTION", getEnvOrDefault("FIRESTORE_RSVP_COUNTERS_COLLECTION", "rsvp_counters")),
		MembershipsCollection:   getEnvOrDefault("MEMBERSHIPS_COLLECTION", getEnvOrDefault("FIRESTORE_MEMBERSHIPS_COLLECTION", "memberships")),
		UseSecretManager:        getEnvAsBool("USE_SECRET_MANAGER", false),
		FCMServerKeySecretName:  secretName,
		FCMServerKey:            os.Getenv("FCM_SERVER_KEY"),
	}

	if cfg.UseSecretManager {
		secretValue, err := fetchSecret(ctx, cfg.GCPProjectID, cfg.FCMServerKeySecretName)
		if err != nil {
			if cfg.FCMServerKey == "" {
				return nil, fmt.Errorf("failed to fetch secret from Secret Manager and no local FCM_SERVER_KEY provided: %w", err)
			}
		} else {
			cfg.FCMServerKey = secretValue
		}
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	return cfg, nil
}

// Validate checks required fields for validity.
func (c *Config) Validate() error {
	p := strings.TrimSpace(c.Port)
	if p == "" {
		return fmt.Errorf("port must not be empty")
	}
	portNum, err := strconv.Atoi(p)
	if err != nil || portNum < 1 || portNum > 65535 {
		return fmt.Errorf("port must be a valid integer between 1 and 65535, got '%s'", c.Port)
	}

	if strings.TrimSpace(c.GCPProjectID) == "" {
		return fmt.Errorf("GCPProjectID must not be empty")
	}
	if strings.TrimSpace(c.FirestoreStateCol) == "" {
		return fmt.Errorf("FirestoreStateCol must not be empty")
	}
	return nil
}

func fetchSecret(ctx context.Context, projectID, secretID string) (string, error) {
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create secret manager client: %w", err)
	}
	defer client.Close()

	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: fmt.Sprintf("projects/%s/secrets/%s/versions/latest", projectID, secretID),
	}

	resp, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		return "", fmt.Errorf("failed to access secret version: %w", err)
	}

	return string(resp.Payload.GetData()), nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if val := os.Getenv(key); strings.TrimSpace(val) != "" {
		return val
	}
	return defaultValue
}

func getEnvAsBool(key string, defaultValue bool) bool {
	valStr := os.Getenv(key)
	if valStr == "" {
		return defaultValue
	}
	val, err := strconv.ParseBool(valStr)
	if err != nil {
		return defaultValue
	}
	return val
}
