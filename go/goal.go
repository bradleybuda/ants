package main

import "container/vector"

type GoalType int

type Goal interface {
	GoalType() GoalType
	IsValid() bool
	Square() *Square
}

type Eat struct {
	destination *Square
	food *Food
}

var EatIndex = make(map[*Square]map[*Food]*Eat)

func (state *State) AllEat() vector.Vector {
	results := vector.Vector{}

	for _, f := range AllFood() {
		food := f.(*Food)
		for _, neighbor := range food.square.Neighbors(state) {
			subMap, ok := EatIndex[neighbor]
			if (ok) {
				eat, _ := subMap[food]
				if (eat == nil) {
					eat = NewEat(neighbor, food)
					subMap[food] = eat
				}

				results.Push(subMap[food])
			}
		}
	}

	return results
}

func NewEat(destination *Square, food *Food) *Eat {
	eat := new(Eat)
	eat.destination = destination
	eat.food = food
	return eat
}
