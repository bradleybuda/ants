package main

//Direction represents the direction concept for issuing orders.
type Direction int

const (
	North Direction = iota
	East
	South
	West

	NoMovement
)

func (d Direction) String() string {
	switch d {
	case North:
		return "n"
	case South:
		return "s"
	case West:
		return "w"
	case East:
		return "e"
	case NoMovement:
		return "-"
	}
	return ""
}
