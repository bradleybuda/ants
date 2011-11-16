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
	Exists() bool
	TimeSinceLastSeen(*State) int
	ObservableByAnyAnt() bool
}

type ItemSet map[*Square]Item

var AllItems = make(ItemSet)

func (items ItemSet) DestroyUnsensed(state *State) {
	for square, item := range items {
		if item.TimeSinceLastSeen(state) == 0 {
			continue
		}

		if item.ObservableByAnyAnt() {
			if item.Exists() {
				square.item = nil
			}
			items[square] = nil, false
		}
	}
}

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

// These won't ever get called for Food - maybe need a sub-interface for OwnableItem?
func (food *Food) IsMine() bool {
	return false;
}

func (food *Food) IsEnemy() bool {
	return false;
}

func (food *Food) ItemType() ItemType {
	return FoodType
}

func (food *Food) Sense(state *State) {
	food.lastSeen = state.Turn
}

func (food *Food) Exists() bool {
	return food.square.item == food
}

func (food *Food) TimeSinceLastSeen(state *State) int {
	return state.Turn - food.lastSeen
}

func (food *Food) ObservableByAnyAnt() bool {
	for _, square := range food.observableFrom {
		if square.(*Square).ant != nil {
			return true
		}
	}

	return false
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

func (hill *Hill) Exists() bool {
	return hill.square.HasHill() && hill.square.item.(*Hill) == hill
}

func (hill *Hill) TimeSinceLastSeen(state *State) int {
	return state.Turn - hill.lastSeen
}

func (hill *Hill) ObservableByAnyAnt() bool {
	for _, square := range hill.observableFrom {
		if square.(*Square).ant != nil {
			return true
		}
	}

	return false
}
