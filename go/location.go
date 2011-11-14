package main

type Location interface {
	Row() int
	Col() int
}

type LocationImpl struct {
	row int
	col int
}

func (li *LocationImpl) Row() int {
	return li.row
}

func (li *LocationImpl) Col() int {
	return li.col
}

// TODO i think i need to implement "equality" as well

func AddOffsetToLocation(state *State, offset Offset, location Location) Location {
	newRow := state.NormalizeRow(offset.row + location.Row())
	newCol := state.NormalizeCol(offset.col + location.Col())
	return &LocationImpl{newRow, newCol}
}