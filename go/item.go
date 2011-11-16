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
	Sense()
	Exists() bool
	TimeSinceLastSeen() int
	ObservableByAnyAnt() bool
}

type BaseItem struct {
	itemType       ItemType
	state          *State
	square         *Square
	lastSeen       int
	observableFrom *SquareSet
}

func (state *State) NewItem(itemType ItemType, square *Square) BaseItem {
	return BaseItem{itemType, state, square, state.Turn, nil}
}

func (item *BaseItem) ItemType() ItemType {
	return item.itemType
}

func (item *BaseItem) Sense() {
	item.lastSeen = item.state.Turn
}

func (item *BaseItem) TimeSinceLastSeen() int {
	return item.state.Turn - item.lastSeen
}

func (item *BaseItem) ObservableByAnyAnt() bool {
	if item.observableFrom == nil {
		item.observableFrom = item.square.VisibleSquares(item.state)
	}

	for _, square := range *item.observableFrom {
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
		if item.TimeSinceLastSeen() == 0 {
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
}

func AllFood() vector.Vector {
	results := vector.Vector{}
	for _, item := range AllItems {
		if item.ItemType() == FoodType {
			results.Push(item)
		}
	}

	return results
}

func (state *State) NewFood(square *Square) *Food {
	newFood := new(Food)
	newFood.BaseItem = state.NewItem(FoodType, square)

	square.item = newFood
	AllItems[square] = newFood

	return newFood
}

// These won't ever get called for Food - maybe need a sub-interface for OwnableItem?
func (food *Food) IsMine() bool {
	return false
}

func (food *Food) IsEnemy() bool {
	return false
}

func (food *Food) Exists() bool {
	return food.square.item == food
}

type Hill struct {
	BaseItem
	owner  int
}

func (state *State) NewHill(owner int, square *Square) *Hill {
	newHill := new(Hill)
	newHill.BaseItem = state.NewItem(HillType, square)

	newHill.owner = owner
	square.item = newHill
	AllItems[square] = newHill

	return newHill
}

func (hill *Hill) IsMine() bool {
	return hill.owner == 0
}

func (hill *Hill) IsEnemy() bool {
	return hill.owner != 0
}

func (hill *Hill) Exists() bool {
	return hill.square.item == hill
}
