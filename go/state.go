package main

import "container/vector"

//State keeps track of everything we need to know about the state of the game
type State struct {
	LoadTime      int //in milliseconds
	TurnTime      int //in milliseconds
	Rows          int //number of rows in the map
	Cols          int //number of columns in the map
	Turns         int //maximum number of turns in the game
	ViewRadius2   int //view radius squared
	AttackRadius2 int //battle radius squared
	SpawnRadius2  int //spawn radius squared
	Turn          int //current turn number

	NextAntId  int
	LivingAnts vector.Vector // maybe make me a hashset?
	Stats      *Stats

	AllSquares SquareSet
	ObservedSquares SquareSet
}

func (s *State) NormalizeRow(row int) int {
	remainder := row % s.Rows
	if remainder < 0 {
		return remainder + s.Rows
	}
	return remainder
}

func (s *State) NormalizeCol(col int) int {
	remainder := col % s.Cols
	if remainder < 0 {
		return remainder + s.Cols
	}
	return remainder
}
