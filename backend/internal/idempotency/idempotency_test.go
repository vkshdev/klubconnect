package idempotency_test

import (
	"context"
	"errors"
	"sync"
	"testing"

	"klubconnect/backend/internal/idempotency"
)

func TestMemoryGuard_LockOrSkip_FirstCall(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	alreadyProcessed, err := guard.LockOrSkip(ctx, "audit_handler", "evt_100")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if alreadyProcessed {
		t.Errorf("expected alreadyProcessed to be false on first call")
	}
}

func TestMemoryGuard_StateTransition_Lock_Complete_Skip(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	// Step 1: Initial Lock
	processed, err := guard.LockOrSkip(ctx, "fcm_handler", "evt_200")
	if err != nil || processed {
		t.Fatalf("step 1 failed: processed=%v, err=%v", processed, err)
	}

	// Step 2: Mark Completed
	if err := guard.MarkCompleted(ctx, "fcm_handler", "evt_200"); err != nil {
		t.Fatalf("step 2 MarkCompleted failed: %v", err)
	}

	// Step 3: Subsequent LockOrSkip should return duplicate (true)
	processed, err = guard.LockOrSkip(ctx, "fcm_handler", "evt_200")
	if err != nil {
		t.Fatalf("step 3 error: %v", err)
	}
	if !processed {
		t.Errorf("expected alreadyProcessed=true on completed event")
	}
}

func TestMemoryGuard_StateTransition_Lock_Fail_Retry(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	// Step 1: Initial Lock
	processed, err := guard.LockOrSkip(ctx, "rsvp_handler", "evt_300")
	if err != nil || processed {
		t.Fatalf("step 1 failed: processed=%v, err=%v", processed, err)
	}

	// Step 2: Mark Failed
	failErr := errors.New("database connection timeout")
	if err := guard.MarkFailed(ctx, "rsvp_handler", "evt_300", failErr); err != nil {
		t.Fatalf("step 2 MarkFailed failed: %v", err)
	}

	// Step 3: Retry LockOrSkip should allow execution (false)
	processed, err = guard.LockOrSkip(ctx, "rsvp_handler", "evt_300")
	if err != nil {
		t.Fatalf("step 3 error: %v", err)
	}
	if processed {
		t.Errorf("expected alreadyProcessed=false after failed execution to allow retry")
	}
}

func TestMemoryGuard_ConcurrentCalls(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	var wg sync.WaitGroup
	count := 10
	results := make([]bool, count)

	for i := 0; i < count; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			p, _ := guard.LockOrSkip(ctx, "membership_handler", "evt_400")
			results[idx] = p
		}(i)
	}

	wg.Wait()

	falseCount := 0
	for _, res := range results {
		if !res {
			falseCount++
		}
	}

	if falseCount != 1 {
		t.Errorf("expected exactly 1 concurrent caller to acquire lock (false), got %d", falseCount)
	}
}

func TestMemoryGuard_ExecuteWrapper(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	executionCount := 0
	fn := func(ctx context.Context) error {
		executionCount++
		return nil
	}

	// First execution should run fn
	err := guard.Execute(ctx, "test_handler", "evt_500", fn)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if executionCount != 1 {
		t.Errorf("expected executionCount 1, got %d", executionCount)
	}

	// Second execution should skip fn
	err = guard.Execute(ctx, "test_handler", "evt_500", fn)
	if err != nil {
		t.Fatalf("expected no error on duplicate, got %v", err)
	}
	if executionCount != 1 {
		t.Errorf("expected executionCount still 1 after duplicate run, got %d", executionCount)
	}

	// Execution returning error should set failed state and fail
	failFn := func(ctx context.Context) error {
		return errors.New("something went wrong")
	}

	err = guard.Execute(ctx, "test_handler", "evt_600", failFn)
	if err == nil {
		t.Errorf("expected error from failFn, got nil")
	}

	// Retrying after failure should execute again
	retryRan := false
	retryFn := func(ctx context.Context) error {
		retryRan = true
		return nil
	}
	err = guard.Execute(ctx, "test_handler", "evt_600", retryFn)
	if err != nil {
		t.Fatalf("expected retry to succeed, got %v", err)
	}
	if !retryRan {
		t.Errorf("expected retryFn to execute after previous failure")
	}
}

func TestMemoryGuard_HighConcurrencyStress(t *testing.T) {
	guard := idempotency.NewMemoryGuard()
	ctx := context.Background()

	// Stress test with 500 goroutines on the same event ID
	var wg sync.WaitGroup
	count := 500
	acquiredCount := 0
	var mu sync.Mutex

	for i := 0; i < count; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			alreadyProcessed, err := guard.LockOrSkip(ctx, "stress_handler", "stress_evt_999")
			if err != nil {
				t.Errorf("unexpected error during LockOrSkip: %v", err)
				return
			}
			if !alreadyProcessed {
				mu.Lock()
				acquiredCount++
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	if acquiredCount != 1 {
		t.Errorf("expected exactly 1 goroutine out of 500 to acquire lock, got %d", acquiredCount)
	}
}

