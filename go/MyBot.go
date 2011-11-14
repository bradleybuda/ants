package main

import (
	"container/vector"
	"container/heap"
	"log"
	"os"
	"syslog"
)

type Route []*Square

type SearchNode struct {
	square *Square
	goal Goal
	route Route
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
		updated += ant.square.Visit(s)
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

  // Purge all invalid ant goals
  // TODO can push this down to the second loop
	for _, elt := range s.LivingAnts {
		ant := elt.(Ant)
		if (ant.goal != nil) && (!ant.goal.IsValid()) {
			ant.goal = nil
		}
	}

  // Figure out which goals are new and seed them into the DFS queue
	for _, elt := range s.AllGoals {
		goal := elt.(Goal)
		square := goal.Square()
		if !square.HasGoal(goal) {
			route := make(Route, 0)
			heap.Push(mb.goalQueue, SearchNode{square, goal, route})
		}
	}

	mb.logger.Printf("Search queue has size %v after goal generation", mb.goalQueue.Len())

	searchRadius := 0
	searchCount := 0

	// TODO keep track of time and don't loop forever
	for mb.goalQueue.Len() > 0 {
    // visit the first node in the queue and unpack it
    node := heap.Pop(mb.goalQueue).(SearchNode)
		searchRadius = len(node.route)
		searchCount++

		square, goal, route := node.square, node.goal, node.route

    // Purge from queue if no longer valid
		if !goal.IsValid() {
			continue
		}

    // Record the route to this goal on the square
		square.goals[goal] = route

		// put neighboring squares at end of search queue
		for _, neighbor := range square.Neighbors() {
      // TODO instead of skipping, need to put this on a retry queue
			if !neighbor.observed {
				continue
			}

      // Don't enqueue the neighbor if we've already visited it for this goal
			if neighbor.HasGoal(goal) {
				continue
			}

			newRoute := make(Route, 0)
			newRoute = append(newRoute, square)
			newRoute = append(newRoute, route...)

			heap.Push(mb.goalQueue, SearchNode{neighbor, goal, newRoute})
		}

		// TODO restore the plug goal?
		mb.logger.Printf("BFS: done searching. Search count was %v, radius was at most %v square from goals", searchCount, searchRadius)
	}

	//returning an error will halt the whole program!
	return nil
}
