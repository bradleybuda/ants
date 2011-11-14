package main

type Stats struct {
	water float64
	observed float64
	visited float64
	food float64
	my_ants float64
	enemy_ants float64
	my_hills float64
	enemy_hills float64
}

// TODO new instead of mutate?
func (stats *Stats) Update(s *State) {
}