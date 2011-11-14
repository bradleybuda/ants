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

  LivingAnts vector.Vector
	Stats *Stats
	Squares map[Location]Square
}

func (s *State) SetStats(stats *Stats) {
}
