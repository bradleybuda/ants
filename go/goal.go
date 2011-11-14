package main

type GoalType int

type Goal interface {
	GoalType() GoalType
}