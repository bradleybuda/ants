$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

JITTER = 12

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
    # note the presence of any non-water squares
    ant.visible_squares.each { |square| square.observe! }

    # make sure we're not stuck
    valid = ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    next if valid.empty? # stay put

    # is there any food?
    food = Square.all.find_all(&:has_food?)
    target = food.sort_by { |uo| ant.square.distance2(uo) }.first

    # find the closest unexplored square by line-of-sight
    unobserved = Square.all.reject(&:observed?)
    target ||= unobserved.sort_by { |uo| ant.square.distance2(uo) }.first

    # route that way by line-of-sight + jitter (to avoid getting stuck until we have real routing)
    next_step = ant.square.neighbors.reject { |sq| off_limits.member?(sq) }.sort_by { |neighbor| neighbor.distance2(target) + rand(JITTER) }.first
    off_limits.add(next_step)

    ant.order ant.square.direction_to(next_step)
  end
end
