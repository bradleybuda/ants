package main

type ItemType int
const (
	Food = iota
)

type Item interface {
	IsEnemy() bool
	IsMine() bool
	ItemType() ItemType
}
