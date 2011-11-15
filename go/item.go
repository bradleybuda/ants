package main

import (
	"container/vector"
)

type ItemType int
const (
	FoodType = iota
	HillType
	EnemyAntType
)

type Item interface {
	IsEnemy() bool
	IsMine() bool
	ItemType() ItemType
	Sense(*State)
}

var AllItems = make(map[Location]Item)

type Food struct {
	square *Square
	observableFrom vector.Vector
	lastSeen int
}

func NewFood(state *State, square *Square) *Item {
	location := square.location

	// create a new food item only if necessary
	existing, ok := AllItems[location]
	if (!ok || existing.ItemType() != FoodType) {
		newFood := new(Food)
		newFood.square = square
		newFood.observableFrom = square.VisibleSquares(state)
		square.item = newFood
		AllItems[location] = newFood
	}

	food := AllItems[location]
	food.Sense(state)

	return &food
}

func (food *Food) Sense(state *State) {
	food.lastSeen = state.Turn
}

func (food *Food) ItemType() ItemType {
	return FoodType
}

// These won't ever get called for Food - maybe need a sub-interface for OwnableItem?
func (food *Food) IsMine() bool {
	return false;
}

func (food *Food) IsEnemy() bool {
	return false;
}
