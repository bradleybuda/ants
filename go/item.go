package main

type ItemType int
const (
	Food = iota
	Hill
	EnemyAnt
)

type Item interface {
	IsEnemy() bool
	IsMine() bool
	ItemType() ItemType
}
