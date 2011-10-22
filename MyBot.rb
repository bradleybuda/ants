$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'

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
    square = ant.square
    # mark current square visited
    square.observe!

    neighbors = square.neighbors
    valid = neighbors.reject { |neighbor| next_destinations.include?(neighbor) }
    next if neighbors.empty? # blocked by pending moves

    # find unexplored
    unexplored = neighbors.reject do |neighbor|
      neighbor.observed?
    end

    # explore randomly but move with intent in an explored area
    destination = unexplored.rand || neighbors.rand
    next_destinations.add(destination)

    ant.order square.direction_to(destination)
  end
end
