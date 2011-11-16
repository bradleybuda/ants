package main

import "time"

func RunTimeoutLoop(durationNanos int64, body func() bool) {
	startNanos := time.Nanoseconds()
	cutoff := startNanos + durationNanos
	iterations := 0

	for body() {
		iterations++
		if time.Nanoseconds() > cutoff {
			break
		}
	}

	Log.Printf("Loop completed %v iterations in %v nanos", iterations, time.Nanoseconds()-startNanos)
}
