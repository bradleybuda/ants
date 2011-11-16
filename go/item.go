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

type BaseItem struct {
	lastSeen int
	observableFrom SquareSet
}

func (item *BaseItem) Sense(state *State) {
	item.lastSeen = state.Turn
}

func (item *BaseItem) TimeSinceLastSeen(state *State) int {
	return state.Turn - item.lastSeen
}

func (item *BaseItem) ObservableByAnyAnt() bool {
	for _, square := range item.observableFrom {
		if square.ant != nil {
			return true
		}
	}

	return false
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
			Log.Printf("Item %v should be visible, but it's not there; must have disappeared", item)
			items[square] = nil, false
		}
	}
}

type Food struct {
	BaseItem
	square *Square
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

func (food *Food) Exists() bool {
	return food.square.item == food
}

type Hill struct {
	BaseItem
	owner int
	square *Square
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
