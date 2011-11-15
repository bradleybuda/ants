package main

import (
	"container/vector"
	"log"
	"math"
)

type Square struct {
	state *State
	location Location
	observed bool
	visited bool
	item Item
	goals map[Goal]Route
	ant *Ant
	nextAnt *Ant
}

func (state *State) CreateSquares() {
	state.AllSquares = make(SquareSet)

	for row := 0; row < state.Rows; row++ {
		for col := 0; col < state.Cols; col++ {
			loc := NewLocation(state, row, col)
			square := Square{state, loc, false, false, nil, make(map[Goal]Route), nil, nil} // TODO square initializer
			state.AllSquares.Add(&square)
		}
	}
}

func (state *State) SquareAtLocation(loc Location) *Square {
	square := state.AllSquares[loc]
	if square == nil {
		log.Panicf("No square at location %v", loc.RowColString(state))
	}
	return square

}

func (state *State) SquareAtRowCol(row int, col int) *Square {
	loc := NewLocation(state, row, col)
	return state.SquareAtLocation(loc)
}

func (state *State) ResetSquares() {
	for _, square := range state.AllSquares {
		square.nextAnt = nil
		square.ant = nil
	}
}

type Offset struct {
	row int
	col int
}

var visibilityMask *vector.Vector = nil

var Directions = map[Direction] Offset {
	East: Offset{ 0,  1},
	West: Offset{ 0, -1},
	North: Offset{ 1,  0},
	South: Offset{-1,  0},
}

func (square *Square) String() string {
	return square.location.RowColString(square.state)
}

func (square *Square) DirectionTo(state *State, adjacent *Square) Direction {
	for direction, offset := range Directions {
		directionLoc := AddOffsetToLocation(state, offset, square.location)
		if directionLoc == adjacent.location {
			return direction
		}
	}

	panic("Square is not adjacent!")
}

func Abs(i int) int {
	if (i < 0) {
		return -1 * i
	}

	return i
}

func Min(i, j int) int {
	if (i < j) {
		return i
	}

	return j
}

func Distance2(state *State, r1, c1, r2, c2 int) int {
	rdelt := Abs(r1 - r2)
  cdelt := Abs(c1 - c2)
  dr := Min(rdelt, state.Rows - rdelt)
  dc := Min(cdelt, state.Cols - cdelt)
  return dr*dr + dc*dc
}

func (square *Square) Visit(state *State) int {
	if square.visited {
		return 0
	}

	square.visited = true

	observedCount := 0
	for _, elt := range square.VisibleSquares(state) {
		vis := elt.(*Square)
		if !vis.observed {
			vis.Observe(state)
			observedCount++
		}
	}

	return observedCount
}

func (square *Square) VisibleSquares(state *State) vector.Vector {
	// build the visiblity mask if it's never been initialized before
	if visibilityMask == nil {
		visibilityMask = new(vector.Vector)

		viewRadius := (int)(math.Ceil(math.Sqrt((float64)(state.ViewRadius2))))
		for rowOffset := -1 * viewRadius ; rowOffset <= viewRadius; rowOffset++ {
			for colOffset := -1 * viewRadius ; colOffset <= viewRadius; colOffset++ {
				if Distance2(state, 0, 0, rowOffset, colOffset) < state.ViewRadius2 {
					visibilityMask.Push(Offset{rowOffset, colOffset})
				}
			}
		}
	}

	// apply the visibility mask to this square
	// TODO memoize result?
	visible := vector.Vector{}
	for _, elt := range *visibilityMask {
		offset := elt.(Offset)
		otherLocation := AddOffsetToLocation(state, offset, square.location)
		otherSquare, ok := state.AllSquares[otherLocation]
		if ok {
			visible.Push(otherSquare)
		}
	}

	return visible
}

func (square *Square) Observe(state *State) {
	square.observed = true
}

func (square *Square) HasFood() bool {
	return (square.item != nil) && (square.item.ItemType() == FoodType)
}

func (square *Square) HasHill() bool {
	return (square.item != nil) && (square.item.ItemType() == HillType)
}

func (square *Square) HasEnemyAnt() bool {
	return (square.item != nil) && (square.item.ItemType() == EnemyAntType)
}

func (square *Square) HasGoal(goal Goal) bool {
	_, ok := square.goals[goal]
	return ok;
}

func (square *Square) Neighbors(state *State) SquareSet {
	neighbors := make(SquareSet)
	offsets := [4]Offset{Offset{-1, 0}, Offset{1, 0}, Offset{0, -1}, Offset{0, 1}}
	for _, offset := range offsets {
		location := AddOffsetToLocation(state, offset, square.location)
		square := state.SquareAtLocation(location)
		neighbors.Add(square)
	}

	return neighbors
}

func (square *Square) Blacklist(state *State) SquareSet {
	blacklist := make(SquareSet)
	for _, neighbor := range square.Neighbors(state) {
		if (neighbor.nextAnt != nil) || neighbor.HasFood() || (neighbor.HasHill() && neighbor.item.IsMine()) {
			blacklist.Add(neighbor)
		}
	}

	return blacklist
}