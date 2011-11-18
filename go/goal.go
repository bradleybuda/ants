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

type GoalId int

var nextGoalId GoalId = 0
var AllGoals map[GoalId]Goal = make(map[GoalId]Goal)

func (id GoalId) Goal() Goal {
	return AllGoals[id]
}

type Goal interface {
	Id() GoalId
	GoalType() GoalType
	IsValid() bool
	Priority() float64
	String() string
	Destination() *Square
	AddAnt(*Ant)
	Die()
}

type DestinationGoal struct {
	id          GoalId
	destination *Square
	ants        []*Ant
}

func (state *State) GenerateGoals() {
	state.GenerateEat()
	state.GenerateExplore()
}

func NewDestinationGoal(destination *Square) *DestinationGoal {
	// intentionally do not add the goal to the destination square; let MyBot do that
	goal := &DestinationGoal{nextGoalId, destination, make([]*Ant, 0)}
	nextGoalId++
	return goal
}

func (goal *DestinationGoal) Id() GoalId {
	return goal.id
}

func (goal *DestinationGoal) Destination() *Square {
	return goal.destination
}

func (goal *DestinationGoal) AddAnt(ant *Ant) {
	goal.ants = append(goal.ants, ant)
}

func (goal *DestinationGoal) Die() {
	// clear any ants participating in this goal
	for _, ant := range goal.ants {
		ant.goal = nil
	}

	// remove from master index
	AllGoals[goal.id] = nil, false

	// remove routes to the goal from the map
	goal.RemoveFromSquare(goal.destination)
}

func (goal *DestinationGoal) RemoveFromSquare(square *Square) {
	_, ok := square.goals[goal.id]
	if ok {
		square.goals[goal.id] = nil, false
		for _, neighbor := range square.Neighbors() {
			goal.RemoveFromSquare(neighbor)
		}
	}
}

func PickWanderForAnt(state *State, ant *Ant) []*Square {
	valid := ant.square.Neighbors().Minus(ant.square.Blacklist())
	if len(valid) == 0 {
		return make(Route, 0)
	}

	var randomSquare *Square = nil
	maxScore := -1.0
	for _, neighbor := range valid {
		// better to wander to a square that's well-connected
		neighborValid := neighbor.Neighbors().Minus(neighbor.Blacklist())
		score := rand.Float64() * (float64)(len(neighborValid))

		// best to wander to a square we've never visited
		if !neighbor.visited {
			score += 3.0
		}

		if score > maxScore {
			maxScore = score
			randomSquare = neighbor
		}
	}

	route := make(Route, 1)
	route[0] = randomSquare
	return route
}

type Eat struct {
	*DestinationGoal
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

func (eat *Eat) String() string {
	return fmt.Sprintf("[Eat food at %v from %v]", eat.food.square, eat.destination)
}

// TODO nothing ever cleans this index up
var EatIndex = make(map[*Square]map[*Food]*Eat)

func (state *State) GenerateEat() {
	for _, food := range AllFood() {
		for _, neighbor := range food.square.Neighbors() {
			_, ok := EatIndex[neighbor]
			if !ok {
				EatIndex[neighbor] = make(map[*Food]*Eat)
			}

			_, okAgain := EatIndex[neighbor][food]
			if !okAgain {
				EatIndex[neighbor][food] = NewEat(neighbor, food)
			}
		}
	}
}

func NewEat(destination *Square, food *Food) *Eat {
	if destination == nil {
		panic("destination nil!")
	}

	if food == nil {
		panic("food nil!")
	}

	eat := new(Eat)
	eat.DestinationGoal = NewDestinationGoal(destination)
	eat.food = food

	AllGoals[eat.Id()] = eat

	return eat
}

type Explore struct {
	*DestinationGoal
}

var ExploreIndex = make(map[*Square]*Explore)

func (state *State) GenerateExplore() {
	for _, square := range state.ObservedSquares {
		if square.IsFrontier() {
			_, ok := ExploreIndex[square]
			if !ok {
				ExploreIndex[square] = NewExplore(square)
			}
		}
	}
}

func NewExplore(destination *Square) *Explore {
	if destination == nil {
		panic("destination nil!")
	}

	explore := &Explore{NewDestinationGoal(destination)}

	AllGoals[explore.Id()] = explore

	return explore
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

/* Goal idea for escort - every ant is constantly drawing a route as
 it goes (all squares visited). When an ant is pursuing a goal, that
 route "activates" and any ants on the route can follow it as a goal
 (instead of wandering).

 In other words, if Ant A has no goal, and the square it is on has Ant B's history s.t. Ant B has a goal, then Ant A's route becoms B's history
*/

