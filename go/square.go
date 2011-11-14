package main

import (
	"container/vector"
	"math"
)

type Square struct {
	location Location
	observed bool
	visited bool
	item Item
}

type SquareSet map[Location]*Square

func (set *SquareSet) Add(square *Square) {
	(*set)[square.location] = square
}

type Offset struct {
	row int
	col int
}

var visibilityMask *vector.Vector = nil

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
	state.ObservedSquares.Add(square)
}

func (square *Square) HasFood() bool {
	return (square.item != nil) && (square.item.ItemType() == Food)
}

func (square *Square) HasHill() bool {
	return (square.item != nil) && (square.item.ItemType() == Hill)
}

func (square *Square) HasEnemyAnt() bool {
	return (square.item != nil) && (square.item.ItemType() == EnemyAnt)
}

func (square *Square) HasGoal(goal Goal) bool {
	return false; // TODO implement
}