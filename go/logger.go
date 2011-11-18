package main

//import "os"
//import "log"
//import "syslog"
//var Log = syslog.NewLogger(syslog.LOG_DEBUG, 0)

type DummyLogger int
var Log DummyLogger = 42
func (_ DummyLogger) Printf(format string, v ...interface{}) {
}
func (_ DummyLogger) Panicf(format string, v ...interface{}) {
}
