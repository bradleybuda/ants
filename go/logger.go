package main

import "syslog"

var Log = syslog.NewLogger(syslog.LOG_DEBUG, 0)
