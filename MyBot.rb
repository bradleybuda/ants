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
  # don't run in to yourself or switch places with a buddy
  off_limits = Set.new

  ai.my_ants.each do |ant|
    square = ant.square
    off_limits.add square
    square.observe!

    neighbors = square.neighbors
    valid = neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    next if neighbors.empty? # blocked by pending moves

    # find unexplored
    unexplored = neighbors.reject do |neighbor|
      neighbor.observed?
    end

    # explore deterministically but unstick yourself randomly
    destination = unexplored.first || neighbors.rand
    off_limits.add(destination)

    ant.order square.direction_to(destination)
  end
end
