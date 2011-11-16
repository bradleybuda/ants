package main

//import "syslog"
//var Log = syslog.NewLogger(syslog.LOG_DEBUG, 0)

import "os"
import "log"

type DummyWriter struct{}

func (*DummyWriter) Write(p []byte) (n int, err os.Error) {
	return len(p), nil
}

var Log = log.New(new(DummyWriter), "", 0)
