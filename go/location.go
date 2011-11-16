package main

import "fmt"

type Location int

func NewLocation(state *State, row int, col int) Location {
	if row < 0 {
		panic("negative row!")
	}
	if col < 0 {
		panic("negative col!")
	}

	return (Location)(((row % state.Rows) * state.Cols) + (col % state.Cols))
}

func (l Location) Row(state *State) int {
	return (int)(l) / state.Cols
}

func (l Location) Col(state *State) int {
	return (int)(l) % state.Cols
}

func (l Location) RowColString(state *State) string {
	return fmt.Sprintf("[%v, %v]", l.Row(state), l.Col(state))
}

// TODO i think i need to implement "equality" as well

func AddOffsetToLocation(state *State, offset Offset, location Location) Location {
	newRow := state.NormalizeRow(offset.row + location.Row(state))
	newCol := state.NormalizeCol(offset.col + location.Col(state))
	return NewLocation(state, newRow, newCol)
}
