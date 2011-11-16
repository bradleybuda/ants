package main

import (
	"container/vector"
	"fmt"
	"rand" // TODO seed
)

type GoalType int
const (
	EatType = iota
	WanderType
)


type Goal interface {
	GoalType() GoalType
	IsValid() bool
	Priority() float64
	String() string
}

type Eat struct {
	destination *Square
	food *Food
}

func (eat *Eat) GoalType() GoalType {
	return EatType
}

func (eat *Eat) IsValid() bool {
	return eat.food.Exists()
}

func (eat *Eat) Priority() float64 {
	return 9.9 // TODO
}

func (eat *Eat) Square() *Square {
	return eat.destination
}

func (eat *Eat) String() string {
	return fmt.Sprintf("[Eat food at %v from %v]", eat.food.square, eat.destination)
}

var EatIndex = make(map[*Square]map[*Food]*Eat)

func (state *State) AllEat() vector.Vector {
	results := vector.Vector{}

	for _, f := range AllFood() {
		food := f.(*Food)
		for _, neighbor := range food.square.Neighbors() {
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

type Wander struct {}

var WanderInstance = new(Wander)

func (_ *Wander) pickRouteForAnt(state *State, ant *Ant) []*Square {
	valid := ant.square.Neighbors().Minus(ant.square.Blacklist())
	var randomSquare *Square = nil
	maxScore := 0.0
	for _, square := range valid {
		score := rand.Float64() * (float64)(len(square.Neighbors()))
		if score > maxScore {
			maxScore = score
			randomSquare = square
		}
	}

	route := make([]*Square, 1)
	route[0] = randomSquare
	return route
}

func (*Wander) Priority() float64 {
	return 0.0 // TODO
}

func (*Wander) GoalType() GoalType {
	return WanderType
}

func (*Wander) IsValid() bool {
	return false // only lasts one turn
}

func (*Wander) String() string {
	return "[Wander randomly]"
}
