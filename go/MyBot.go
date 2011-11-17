package main

import (
	"os"
)

type MyBot struct {
	goalQueue *SearchQueue
}

//NewBot creates a new instance of your bot
func NewBot(s *State) Bot {
	mb := new(MyBot)
	mb.goalQueue = NewSearchQueue()
	s.ObservedSquares = make(SquareSet)
	s.LivingAnts = make(map[int]*Ant)

	Log.Printf("New bot created!")

	return mb
}

//DoTurn is where you should do your bot's actual work.
func (mb *MyBot) DoTurn(s *State) os.Error {
	Log.Printf("BFS: Search queue has size %v (from previous turns)", mb.goalQueue.Len())

	// Update map visibility
	Log.Printf("Updating visiblity for %v ants", len(s.LivingAnts))
	updated := 0
	for _, ant := range s.LivingAnts {
		updated += ant.square.Visit(s)
	}
	Log.Printf("Updated visiblity of %v squares", updated)

	// restore any newly visible squares to the goalQueue if they were previously set aside
	restoredSearchNodes := 0
	// TODO have an index of newly observed squares to avoid walking all?
	for _, square := range s.ObservedSquares {
		for _, searchNode := range square.deferredSearchNodes {
			mb.goalQueue.Push(searchNode)
			restoredSearchNodes++
		}

		square.deferredSearchNodes = make([]*SearchNode, 0)
	}
	Log.Printf("BFS: Restored %v deferred search nodes from previous turns", restoredSearchNodes)

	// Compute game statistics for weighting model
	s.Stats.Update(s)
	Log.Printf("Current turn statistics are %+v", s.Stats)

	// Make a shared list of goals used by all ants
	// TODO can skip this until we actually need to pick a goal
	Log.Printf("Looking for goals")
	s.GenerateGoals()

	// Loop over all goals and seed them into the search queue if new, or clean them up if invalid
	for _, goal := range AllGoals {
		square := goal.Destination()
		if !square.HasGoal(goal) {
			// Goal is new
			route := make(Route, 0)
			newNode := NewSearchNode(square, goal, route)
			Log.Printf("BFS: Adding seed node: %+v", newNode)
			mb.goalQueue.Push(newNode)
		} else if !goal.IsValid() {
			// Goal should quiesce
			goal.Die()
		} // else do nothing to goal
	}

	Log.Printf("Search queue has size %v after goal generation", mb.goalQueue.Len())

	maxSearchRadius := 10 // hack to limit memory usage
	searchRadius := 0
	searchCount := 0

	searchTimeNanos := (int64)(s.TurnTime * 800000)
	RunTimeoutLoop(searchTimeNanos, func() bool {
		if mb.goalQueue.Len() == 0 {
			return false // stop looping
		}

		// visit the first node in the queue and unpack it
		node := mb.goalQueue.Pop()
		nodeSearchRadius := len(node.route)
		if nodeSearchRadius >= searchRadius {
			searchRadius = nodeSearchRadius
		} else {
			panic("search is not breadth-first!")
		}
		searchCount++

		//Log.Printf("BFS searching %+v", node)
		square, goal, route := node.square, node.goal, node.route

		// Purge from queue if no longer valid
		if !goal.IsValid() {
			return true // next iteration
		}

		// Record the route to this goal on the square
		square.goals[goal.Id()] = route

		// don't search any further from this node if we've maxed out
		if nodeSearchRadius >= maxSearchRadius {
			return true
		}

		// put neighboring squares at end of search queue
		for _, neighbor := range square.Neighbors() {
			//Log.Printf("BFS: looking for new search node at %v", neighbor)

			// Don't enqueue the neighbor if we've already visited it for this goal
			if neighbor.HasGoal(goal) {
				//Log.Printf("BFS: skipping already visited square %v", neighbor)
			} else {
				newRoute := make(Route, 0)
				newRoute = append(newRoute, square)
				newRoute = append(newRoute, route...)
				newNode := NewSearchNode(neighbor, goal, newRoute)

				// Don't try to search nodes we haven't observed yet (they could
				// be water). Instead, set aside those nodes and restore them
				// later
				if !neighbor.observed {
					//Log.Printf("BFS: skipping unobserved square %v", neighbor)
					neighbor.deferredSearchNodes = append(neighbor.deferredSearchNodes, newNode)
				} else {
					//Log.Printf("BFS: Adding new node: %+v", newNode)
					mb.goalQueue.Push(newNode)
				}
			}
		}

		return true // continue looping
	})

	// TODO restore the plug goal?
	Log.Printf("BFS: done searching. Search count was %v, radius was at most %v square from goals", searchCount, searchRadius)

	// Issue orders for each ant's best-available goal
	// TODO this should be treated as a queue, not an array
	for _, ant := range s.LivingAnts {
		// check passable squares
		square := ant.square
		passable := square.Neighbors().Minus(square.Blacklist())

		// try to assign a goal if we don't have one
		if ant.goal == nil {
			Log.Printf("Orders: finding new orders for %v", ant)

			// Iterate through all the square's goals and find the highest priority passable route
			var bestGoal Goal = nil
			for goalId, route := range square.goals {
				passableRoute := (len(route) == 0) || passable.Member(route[0])
				goal := goalId.Goal()
				if passableRoute && (bestGoal == nil || goal.Priority() > bestGoal.Priority()) {
					// TODO break priority ties by route length
					bestGoal = goal
				}
			}

			ant.SetGoal(bestGoal)
		}

		// Execute either the assigned route or a random one
		var route Route = nil
		if ant.goal == nil {
			route = PickWanderForAnt(s, ant)
		} else {
			route = ant.Route()
		}

		Log.Printf("Orders: route for %v is %v", ant, route)
		passableRoute := (len(route) == 0) || passable.Member(route[0])
		if len(route) > 0 && passableRoute {
			ant.OrderTo(s, route[0])
		} else {
			Log.Printf("Route is impassable, doing nothing")
		}
	}

	//returning an error will halt the whole program!
	return nil
}
