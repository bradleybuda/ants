package main

import (
	"fmt"
	"rand"
)

type GoalType int

const (
	EatType = iota
	ExploreType
	WanderType
)

type Goal interface {
	GoalType() GoalType
	IsValid() bool
	Priority() float64
	String() string
	Destination() *Square
}

type DestinationGoal struct {
	destination *Square
}

func (goal *DestinationGoal) Destination() *Square {
	return goal.destination
}

func (state *State) AllGoals() []Goal {
	result := make([]Goal, 0)
	result = append(result, state.AllEat()...)
	result = append(result, state.AllExplore()...)
	return result
}

type Eat struct {
	*DestinationGoal
	food        *Food
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


func (eat *Eat) String() string {
	return fmt.Sprintf("[Eat food at %v from %v]", eat.food.square, eat.destination)
}

var EatIndex = make(map[*Square]map[*Food]*Eat)

func (state *State) AllEat() []Goal {
	results := make([]Goal, 0)

	for _, f := range AllFood() {
		food := f.(*Food)
		for _, neighbor := range food.square.Neighbors() {
			_, ok := EatIndex[neighbor]
			if !ok {
				EatIndex[neighbor] = make(map[*Food]*Eat)
			}

			_, okAgain := EatIndex[neighbor][food]
			if !okAgain {
				EatIndex[neighbor][food] = NewEat(neighbor, food)
			}

			results = append(results, EatIndex[neighbor][food])
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
	eat.DestinationGoal = &DestinationGoal{destination}
	eat.food = food
	return eat
}

type Wander struct{}

var WanderInstance = new(Wander)

func (_ *Wander) PickRouteForAnt(state *State, ant *Ant) []*Square {
	valid := ant.square.Neighbors().Minus(ant.square.Blacklist())
	if len(valid) == 0 {
		return make(Route, 0)
	}

	var randomSquare *Square = nil
	maxScore := 0.0
	for _, square := range valid {
		score := rand.Float64() * (float64)(len(square.Neighbors()))

		if !square.visited {
			score += 3.0
		}

		if score > maxScore {
			maxScore = score
			randomSquare = square
		}
	}

	route := make(Route, 1)
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

func (*Wander) Destination() *Square {
	panic("Don't call me!")
}

type Explore struct {
	*DestinationGoal
}

var ExploreIndex = make(map[*Square]*Explore)

func (state *State) AllExplore() []Goal {
	results := make([]Goal, 0)

	for _, square := range state.ObservedSquares {
		if square.IsFrontier() {
			explore := NewExplore(square)
			ExploreIndex[square] = explore
			results = append(results, explore)
		}
	}

	return results
}

func NewExplore(destination *Square) *Explore {
	if destination == nil {
		panic("destination nil!")
	}

	return &Explore{&DestinationGoal{destination}}
}

func (expore *Explore) GoalType() GoalType {
	return ExploreType
}

func (explore *Explore) IsValid() bool {
	return !explore.destination.visited
}

func (explore *Explore) Priority() float64 {
	return 8.0 // TODO
}

func (explore *Explore) String() string {
	return fmt.Sprintf("Explore destination %v", explore.destination)
}
