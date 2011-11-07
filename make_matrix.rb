#!/usr/bin/env ruby

require 'matrix'
require './params_matrix'

#CONCRETE_GOALS = [:Eat, :Raze, :Kill, :Defend, :Explore, :Escort, :Plug, :Wander]
WEIGHTS =         [255,  255,   128,   1,       200,      20,      10,    2      ]

m = Matrix.build(ParamsMatrix::ROWS, ParamsMatrix::COLS) { |r, c| WEIGHTS[r] }
File.open('matrix', 'w') { |f| ParamsMatrix.write(f, m) }
