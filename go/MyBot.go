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

	// Update map visibility
	mb.logger.Printf("Updating visiblity for %v ants", s.LivingAnts.Len())
	updated := 0
	for _, elt := range s.LivingAnts {
		ant := elt.(Ant)
		updated += ant.Square.Visit(s)
	}
	mb.logger.Printf("Updated visiblity of %v squares", updated)

	// TODO restore any newly visible squares to the goalQueue if they were previously set aside

	// Compute game statistics for weighting model
	s.Stats.Update(s)
	mb.logger.Printf("Current turn statistics are %+v", s.Stats)

  // Make a shared list of goals used by all ants
  // TODO can skip this until we actually need to pick a goal
  mb.logger.Printf("Looking for goals")
	goalStats := make(map[GoalType]*vector.Vector)
	// group goals by type (TODO maybe we should just keep them in this form?)
	for _, elt := range s.AllGoals {
		goal := elt.(Goal)
		goalType := goal.GoalType()
		_, ok := goalStats[goalType]
		if (!ok) {
			goalStats[goalType] = new(vector.Vector)
		}
		goalStats[goalType].Push(goal)
	}
	mb.logger.Printf("Found initial goals: %v", goalStats)


	//returning an error will halt the whole program!
	return nil
}
