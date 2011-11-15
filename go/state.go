package main

import "container/vector"

//State keeps track of everything we need to know about the state of the game
type State struct {
	LoadTime      int   //in milliseconds
	TurnTime      int   //in milliseconds
	Rows          int   //number of rows in the map
	Cols          int   //number of columns in the map
	Turns         int   //maximum number of turns in the game
	ViewRadius2   int   //view radius squared
	AttackRadius2 int   //battle radius squared
	SpawnRadius2  int   //spawn radius squared
	PlayerSeed    int64 //random player seed
	Turn          int   //current turn number

	NextAntId int
  LivingAnts vector.Vector
	Stats *Stats

	AllSquares SquareSet

	AllGoals vector.Vector
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
