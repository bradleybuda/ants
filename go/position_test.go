package main

import "testing"

func TestRowCol(_ *testing.T) {
	state := new(State)
	state.Rows = 30
	state.Cols = 90

	state.CreateSquares()

	a := NewLocation(state, 0, 0)
	b := NewLocation(state, 0, 1)
	c := NewLocation(state, 1, 0)
	d := NewLocation(state, 1, 1)
	println(a, b, c, d)

	println(state.SquareAt(25, 60))
	println(state.SquareAt(65, 65))
}
