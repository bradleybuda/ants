$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'
VISITED_SQUARES = Set.new

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

ai = AI.new

ai.setup do |ai|
  STDERR.puts "Mybot: Setup"
end

ai.run do |ai|
  # don't run in to yourself
  next_destinations = Set.new

  ai.my_ants.each do |ant|
    # mark current square visited
    VISITED_SQUARES.add ant.square.coords

    # find valid moves
    valid = [:N, :E, :S, :W].find_all do |dir|
      neighbor = ant.square.neighbor(dir)
      neighbor.land? && !next_destinations.member?(neighbor.coords)
    end

    # find unexplored
    unexplored = valid.reject do |dir|
      coords = ant.square.neighbor(dir).coords
      VISITED_SQUARES.include?(coords)
    end

    next if valid.empty? # when can this happen?!?

    # explore randomly but move with intent in an explored area
    direction = unexplored.rand || valid.first

    destination = ant.square.neighbor(direction).coords
    next_destinations.add(destination)
    ant.order direction
  end
end
