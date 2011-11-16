package main

import (
	"container/vector"
	"container/heap"
	"fmt"
	"os"
)

type Route []*Square

type SearchNode struct {
	square *Square
	goal Goal
	route Route
}

func (sn SearchNode) String() string {
	return fmt.Sprintf("[Search for a path to %v at %v with existing route %v]", sn.goal, sn.square, sn.route);
}

type GoalQueue struct {
	vector.Vector
}

// i,j are indices of elements to compare
func (gq *GoalQueue) Less(i, j int) bool {
	iElt := gq.At(i).(SearchNode)
	jElt := gq.At(j).(SearchNode)

	return len(iElt.route) < len(jElt.route)
}

type MyBot struct {
	goalQueue *GoalQueue
}

//NewBot creates a new instance of your bot
func NewBot(s *State) Bot {
	mb := new(MyBot)
	mb.goalQueue = new(GoalQueue)
	heap.Init(mb.goalQueue)

	Log.Printf("New bot created!")

	return mb
}

//DoTurn is where you should do your bot's actual work.
func (mb *MyBot) DoTurn(s *State) os.Error {
	Log.Printf("Search queue has size %v (from previous turns)", mb.goalQueue.Len())

	// Update map visibility
	Log.Printf("Updating visiblity for %v ants", s.LivingAnts.Len())
	updated := 0
	for _, elt := range s.LivingAnts {
		ant := elt.(*Ant)
		updated += ant.square.Visit(s)
	}
	Log.Printf("Updated visiblity of %v squares", updated)

	// TODO restore any newly visible squares to the goalQueue if they were previously set aside

	// Compute game statistics for weighting model
	s.Stats.Update(s)
	Log.Printf("Current turn statistics are %+v", s.Stats)

  // Make a shared list of goals used by all ants
  // TODO can skip this until we actually need to pick a goal
  Log.Printf("Looking for goals")

	goalStats := make(map[GoalType]int)
	// group goals by type (TODO maybe we should just keep them in this form?)
	for _, elt := range s.AllEat() { // TODO
		goal := elt.(Goal)
		goalType := goal.GoalType()
		goalStats[goalType]++
	}
	Log.Printf("Found initial goals: %v", goalStats) // TODO this is pretty useless right now

  // Purge all invalid ant goals
  // TODO can push this down to the second loop
	for _, elt := range s.LivingAnts {
		ant := elt.(*Ant)
		if (ant.goal != nil) && (!ant.goal.IsValid()) {
			Log.Printf("%v goal became invalid, clearing it (maybe completed?)", ant)
			ant.goal = nil
		}
	}

  // Figure out which goals are new and seed them into the DFS queue
	for _, elt := range s.AllEat() { // TODO
		eat := elt.(*Eat)
		square := eat.Square()
		if !square.HasGoal(eat) {
			route := make(Route, 0)
			newNode := SearchNode{square, eat, route}
			//Log.Printf("BFS: Adding seed node: %+v", newNode)
			heap.Push(mb.goalQueue, newNode)
		}
	}

	Log.Printf("Search queue has size %v after goal generation", mb.goalQueue.Len())

	searchRadius := 0
	searchCount := 0

	searchTimeNanos := (int64)(s.TurnTime * 700)
	RunTimeoutLoop(searchTimeNanos, func() bool {
		if mb.goalQueue.Len() == 0 {
			return false; // stop looping
		}

    // visit the first node in the queue and unpack it
    node := heap.Pop(mb.goalQueue).(SearchNode)
		searchRadius = len(node.route)
		searchCount++

		//Log.Printf("BFS searching %+v", node)
		square, goal, route := node.square, node.goal, node.route

    // Purge from queue if no longer valid
		if !goal.IsValid() {
			return true; // next iteration
		}

    // Record the route to this goal on the square
		square.goals[goal] = route

		// put neighboring squares at end of search queue
		for _, neighbor := range square.Neighbors() {
			//Log.Printf("BFS: looking for new search node at %v", neighbor)

      // TODO instead of skipping, need to put this on a retry queue
			if !neighbor.observed {
				//Log.Printf("BFS: skipping unobserved square %v", neighbor)
				return true;
			}

      // Don't enqueue the neighbor if we've already visited it for this goal
			if neighbor.HasGoal(goal) {
				//Log.Printf("BFS: skipping already visited square %v", neighbor)
				return true;
			}

			newRoute := make(Route, 0)
			newRoute = append(newRoute, square)
			newRoute = append(newRoute, route...)

			newNode := SearchNode{neighbor, goal, newRoute}
			//Log.Printf("BFS: Adding new node: %+v", newNode)
			heap.Push(mb.goalQueue, newNode)
		}

		return true; // continue iterations
	})

	// TODO restore the plug goal?
	Log.Printf("BFS: done searching. Search count was %v, radius was at most %v square from goals", searchCount, searchRadius)

  // Issue orders for each ant's best-available goal
	// TODO this should be treated as a queue, not an array
	for _, elt := range s.LivingAnts {
		ant := elt.(*Ant)

		Log.Printf("Orders: updating orders for %v", ant)

    // Find the best goal that this square knows about and is passable
		square := ant.square
		passable := square.Neighbors().Minus(square.Blacklist())

		// Iterate through all the square's goals doing two things: purge invalids, and find highest priority
		var bestGoal Goal = WanderInstance
		bestRoute := WanderInstance.PickRouteForAnt(s, ant)

		for goal, route := range square.goals {
			if goal.IsValid() {
				passableRoute := (len(route) == 0) || passable.Member(route[0])
				if goal.Priority() > bestGoal.Priority() && passableRoute {
					// TODO break priority ties by route length
					bestGoal = goal
					bestRoute = route
				}
			} else {
				square.goals[goal] = nil, false
			}
		}

		ant.goal = bestGoal
		Log.Printf("Orders: new route for %v is %v", ant, bestRoute)
		if len(bestRoute) > 0 {
			ant.OrderTo(s, bestRoute[0])
		}
	}

	//returning an error will halt the whole program!
	return nil
}
