package main

import (
	"container/vector"
	"container/heap"
	"log"
	"os"
	"syslog"
)

type SearchNode struct {
	square *Square
	goal *Goal
	route []*Square
}

type GoalQueue struct {
	vector.Vector
}

// i,j are indices of elements to compare
func (gq *GoalQueue) Less(i, j int) bool {
	return false; // TODO
}

type MyBot struct {
	goalQueue *GoalQueue
	logger *log.Logger
}

//NewBot creates a new instance of your bot
func NewBot(s *State) Bot {
	mb := new(MyBot)
	mb.goalQueue = new(GoalQueue)
	heap.Init(mb.goalQueue)

	mb.logger = syslog.NewLogger(syslog.LOG_DEBUG, 0)

	return mb
}

//DoTurn is where you should do your bot's actual work.
func (mb *MyBot) DoTurn(s *State) os.Error {
	mb.logger.Printf("Search queue has size %v (from previous turns)", mb.goalQueue.Len())

	//returning an error will halt the whole program!
	return nil
}
