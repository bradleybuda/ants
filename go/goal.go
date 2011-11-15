package main

import "container/vector"

type GoalType int
const (
	EatType = iota
)


type Goal interface {
	GoalType() GoalType
	IsValid() bool
	Square() *Square
}

type Eat struct {
	destination *Square
	food *Food
}

func (eat *Eat) GoalType() GoalType {
	return EatType
}

func (eat *Eat) IsValid() bool {
	return true // TODO
}

func (eat *Eat) Square() *Square {
	return eat.destination
}

var EatIndex = make(map[*Square]map[*Food]*Eat)

func (state *State) AllEat() vector.Vector {
	results := vector.Vector{}

	for _, f := range AllFood() {
		food := f.(*Food)
		for _, neighbor := range food.square.Neighbors(state) {
			_, ok := EatIndex[neighbor]
			if (!ok) {
				EatIndex[neighbor] = make(map[*Food]*Eat)
			}

			_, okAgain := EatIndex[neighbor][food]
			if (!okAgain) {
				EatIndex[neighbor][food] = NewEat(neighbor, food)
			}

			results.Push(EatIndex[neighbor][food])
		}
	}

	return results
}

func NewEat(destination *Square, food *Food) *Eat {
	if destination == nil {
		panic("destination nil!")
	}

	if food == nil {
		panic("food nil!")
	}

	eat := new(Eat)
	eat.destination = destination
	eat.food = food
	return eat
}
