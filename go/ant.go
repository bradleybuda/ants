package main

import "fmt"

type Ant struct {
	id         int
	square     *Square
	nextSquare *Square
	goal       Goal
}

func (state *State) NewAnt(square *Square) *Ant {
	if square == nil {
		panic("nil square for ant")
	}

	ant := &Ant{state.NextAntId, square, square, nil}

	state.NextAntId++
	square.ant = ant
	square.nextAnt = ant

	state.LivingAnts[ant.id] = ant

	return ant
}

func (state *State) AdvanceAllAnts() {
	for _, ant := range state.LivingAnts {
		ant.square = ant.nextSquare
		ant.square.ant = ant
		ant.square.nextAnt = ant
	}
}

func (ant *Ant) String() string {
	return fmt.Sprintf("Ant %v at %v pursuing %v", ant.id, ant.square, ant.goal)
}

func (ant *Ant) OrderTo(state *State, adjacent *Square) {
	if adjacent == nil {
		panic(fmt.Sprintf("trying to order %v to nil square", ant))
	}

	ant.nextSquare = adjacent
	ant.nextSquare.nextAnt = ant

	state.IssueOrderLoc(ant.square.location, ant.square.DirectionTo(state, adjacent))
}

func (ant *Ant) Die(state *State) {
	state.LivingAnts[ant.id] = nil, false
}

// nil is a valid argument here (is this a good idea?)
func (ant *Ant) SetGoal(goal Goal) {
	ant.goal = goal
	if goal != nil {
		goal.AddAnt(ant)
	}
}

func (ant *Ant) Route() Route {
	return ant.square.goals[ant.goal.Id()]
}

