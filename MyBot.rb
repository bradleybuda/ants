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
  # don't move to a square that an ant is already on because:
  #
  # 1) it's not interesting
  # 2) he might be stuck, in which case this is suicide
  off_limits = Set.new(ai.my_ants.map { |ant| ant.square })

  ai.my_ants.each do |ant|
    square = ant.square
    square.observe!

    valid = square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    next if valid.empty? # blocked by pending moves

    # find unexplored
    unexplored = valid.reject do |neighbor|
      neighbor.observed?
    end

    # explore deterministically but unstick yourself randomly
    destination = unexplored.first || valid.rand
    off_limits.add(destination)

    ant.order square.direction_to(destination)
  end
end
