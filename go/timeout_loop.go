package main

import "time"

func RunTimeoutLoop(durationNanos int64, body func() bool) {
	startNanos := time.Nanoseconds()
	cutoff := startNanos + durationNanos

	for body() {
		if time.Nanoseconds() > cutoff {
			break
		}
	}
}