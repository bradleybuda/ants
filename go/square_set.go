package main

type SquareSet map[Location]*Square

func (set SquareSet) Add(square *Square) {
	set[square.location] = square
}

func (set SquareSet) Remove(square *Square) {
	set[square.location] = nil, false
}

func (set SquareSet) Member(square *Square) bool {
	_, ok := set[square.location]
	return ok
}

func (set SquareSet) Minus(otherSet SquareSet) SquareSet {
	result := make(SquareSet)
	for k, v := range set {
		_, inOther := otherSet[k]
		if !inOther {
			result[k] = v
		}
	}

	return result
}
