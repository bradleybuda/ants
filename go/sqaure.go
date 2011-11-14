package main

type Square struct {
	observed bool
	visited bool
	item Item
}

func (square *Square) Visit() int {
	// TODO implement
	return 0;
}

func (square *Square) HasFood() bool {
	// TODO implement
	return false;
}

func (square *Square) HasHill() bool {
	// TODO implement
	return false;
}

func (sqaure *Square) HasEnemyAnt() bool {
	return false;
}