#!/usr/bin/env ruby

#CONCRETE_GOALS = [Eat, Raze, Kill, Defend, Explore, Escort, Plug, Wander]
WEIGHTS = [1000, 800, 100, 10, 700, 20, 10, 1]

matrix = Array.new(64) { |i| WEIGHTS[i % 8] }
packed = matrix.pack("L*")
File.open('matrix', 'w') { |f| f.binmode; f.write(packed) }
