package main

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

func (ant *Ant) OrderTo(state *State, adjacent *Square) {
	ant.nextSquare = adjacent
	ant.nextSquare.nextAnt = ant

	state.IssueOrderLoc(ant.square.location, ant.square.DirectionTo(state, adjacent))
}