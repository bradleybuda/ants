package main

import "fmt"

type Ant struct {
	id int
	square *Square
	nextSquare *Square
	goal Goal
}

func (state *State) NewAnt(square *Square) *Ant {
	if (square == nil) {
		panic("nil square for ant")
	}

	ant := new(Ant)
	ant.square = square
	ant.nextSquare = square
	square.ant = ant
	square.nextAnt = ant

	ant.id = state.NextAntId
	state.NextAntId++

	state.LivingAnts.Push(ant)

	return ant
}

func (state *State) AdvanceAllAnts() {
	for _, elt := range state.LivingAnts {
		ant := elt.(*Ant)
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
	for idx, elt := range state.LivingAnts {
		if elt.(*Ant) == ant {
			state.LivingAnts.Delete(idx)
			return
		}
	}
}