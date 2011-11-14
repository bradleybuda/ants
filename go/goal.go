package main

type GoalType int

type Goal interface {
	GoalType() GoalType
	IsValid() bool
	Square() *Square
}