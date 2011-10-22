$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'

def weight(ai, type)
  case type
  when :food then 1_000 * (15.0 / ai.my_ants.count)
  when :raze then 500 * (ai.my_ants.count / 10.0)
  when :kill then 300 * (ai.my_ants.count / 15.0)
  when :explore then 200
  when :random then 1
  end
end

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

ai = AI.new

ai.setup do |ai|
  log "Mybot: Setup"
end

ai.run do |ai|
  # Update map and off_limits based on ant positions
  off_limits = Set.new
  ai.my_ants.each do |ant|
    # don't move to a square that an ant is already on because:
    #
    # 1) it's not interesting
    # 2) he might be stuck, in which case this is suicide
    off_limits.add(ant.square)

    # note the presence of any non-water squares
    ant.visible_squares.each { |square| square.observe! }
  end

  # These lists are useful to all ants - all
  destinations = Square.all.map do |square|
    if square.has_food?
      [:food, square]
    elsif !square.observed?
      [:explore, square]
    elsif square.hill && square.hill != 0
      [:raze, square]
#    elsif square.hill && square.hill.owner == 0 # have to work on defend because we can't plug our hill
#      [:defend, square]
    elsif square.ant && square.ant.enemy?
      [:kill, square]
    end
  end.compact

  # If there's absolutely nowhere to go
  destinations = [[:random, Square.all.rand]] if destinations.empty?

  ai.my_ants.each do |ant|
    log "Where should ant at #{ant.row}, #{ant.col} go?"

    # make sure we're not stuck
    valid = ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    next if valid.empty? # stay put

    # pick a destination based on proximity and a weighting factor
    type, destination = destinations.min_by { |type, square| Math.sqrt(ant.square.distance2(square)) / weight(ai, type) }
    log "Destination is #{type} at #{destination.row}, #{destination.col}"

    # take the first step, unless it's off limits; then take a random step
    # TODO should be able to cache this route with the ant and have it remember its plan, only recompute if plan goes invalid
    route = ant.square.route_to(destination)
    next_step = if route
                  route.first
                else
                  valid.rand
                end
    next_step = valid.rand unless valid.member?(next_step)

    off_limits.add(next_step)
    ant.order ant.square.direction_to(next_step)
  end
end
