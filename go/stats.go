package main

type Stats struct {
	water      float64
	observed   float64
	visited    float64
	food       float64
	myAnts     float64
	enemyAnts  float64
	myHills    float64
	enemyHills float64
}

// TODO new instead of mutate?
func (stats *Stats) Update(s *State) {
	totalSpace := (float64)(s.Rows * s.Cols)
	nonWater, observed, visited, food, enemyAnts, myHills, enemyHills := 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

	for _, square := range s.AllSquares {
		nonWater++
		if square.observed {
			observed++
		}
		if square.visited {
			visited++
		}
		if square.HasFood() {
			food++
		}
		if square.HasHill() && square.item.IsEnemy() {
			enemyHills++
		}
		if square.HasHill() && square.item.IsMine() {
			myHills++
		}
		if square.HasEnemyAnt() {
			enemyAnts++
		}
		myAnts := (float64)(len(s.LivingAnts))

		// These are rates instead of ratios to avoid low-precision
		// floats. They're not intuitive - just statistics to be used by the
		// algorithm
		stats.water = totalSpace / (totalSpace - nonWater)
		stats.observed = totalSpace / observed
		stats.visited = totalSpace / visited
		stats.food = totalSpace / (food + 1)
		stats.myAnts = totalSpace / (myAnts + 1)
		stats.enemyAnts = totalSpace / (enemyAnts + 1)
		stats.myHills = totalSpace / (myHills + 1)
		stats.enemyHills = totalSpace / (enemyHills + 1)
		// TODO add enemy count
	}
}
