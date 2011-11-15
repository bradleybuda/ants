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

var AllItems = make(map[*Square]Item)

type Food struct {
	square *Square
	observableFrom vector.Vector
	lastSeen int
}

func AllFood() vector.Vector {
	results := vector.Vector{}
	for _, item := range AllItems {
		if (item.ItemType() == FoodType) {
			results.Push(item)
		}
	}

	return results
}

func (state *State) NewFood(square *Square) *Food {
	newFood := new(Food)

	newFood.square = square
	square.item = newFood
	newFood.observableFrom = square.VisibleSquares(state)
	AllItems[square] = newFood

	newFood.Sense(state)

	return newFood
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

type Hill struct {
	owner int
	square *Square
	observableFrom vector.Vector
	lastSeen int
}

func (state *State) NewHill(owner int, square *Square) *Hill {
	newHill := new(Hill)

	newHill.owner = owner

	newHill.square = square
	square.item = newHill
	newHill.observableFrom = square.VisibleSquares(state)
	AllItems[square] = newHill

	newHill.Sense(state)

	return newHill
}

func (hill *Hill) Sense(state *State) {
	hill.lastSeen = state.Turn
}

func (food *Hill) ItemType() ItemType {
	return HillType
}

func (hill *Hill) IsMine() bool {
	return hill.owner == 0
}

func (hill *Hill) IsEnemy() bool {
	return hill.owner != 0
}

