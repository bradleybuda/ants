package main

import "time"

func RunTimeoutLoop(durationNanos int64, body func() bool) {
	iterations := 0
	timedOut := false
	timer := time.AfterFunc(durationNanos, func() {
		timedOut = true
	})

	for !timedOut && body() {
		iterations++
	}

	if timer.Stop() {
		Log.Printf("Finished %v iterations without timing out", iterations)
	} else {
		Log.Printf("Timed out after finishing %v iterations", iterations)
	}
}
