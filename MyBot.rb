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

def pick_goal(ai, destinations, ant)
  # pick a destination based on proximity and a weighting factor
  type, destination = destinations.min_by { |type, square| Math.sqrt(ant.square.distance2(square)) / weight(ai, type) }
  log "Goal is #{type} at #{destination.row}, #{destination.col}"
  [type, destination]
end

# TODO combine this with other logic
def valid_goal?(goal)
  type, destination = *goal

  # double-check to make sure the destination still exists
  if Square.at(destination.row, destination.col).nil?
    return false
  end

  case type
  when :food
    destination.has_food?
  when :explore
    !destination.observed?
  when :raze
    destination.hill && destination.hill != 0
  when :defend
    destination.hill && destination.hill.owner == 0
  when :kill
    destination.ant && destination.ant.enemy?
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
  log "Looking for destinations"
  destinations = Square.all.map do |square|
    if square.has_food?
      [:food, square]
    elsif square.frontier?
      [:explore, square]
    elsif square.hill && square.hill != 0
      [:raze, square]
#    elsif square.hill && square.hill.owner == 0 # have to work on defend because we can't plug our hill
#      [:defend, square]
    elsif square.ant && square.ant.enemy?
      [:kill, square]
    end
  end.compact
  log "Found #{destinations.size} possible destinations"

  # If there's absolutely nowhere to go
  destinations = [[:random, Square.all.rand]] if destinations.empty?

  ai.my_ants.each do |ant|
    # make sure we're not stuck
    valid = ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    if valid.empty?
      log "Ant #{ant.id} at #{ant.row}, #{ant.col} is stuck, staying put"
      next
    end

    if ant.goal.nil?
      log "Ant #{ant.id} at #{ant.row}, #{ant.col} has no goal, needs a new one"
      ant.goal = pick_goal(ai, destinations, ant)
    elsif !valid_goal?(ant.goal)
      log "Ant #{ant.id} at #{ant.row}, #{ant.col} can no longer execute goal, needs a new one"
      ant.goal = pick_goal(ai, destinations, ant)
    else
      log "Ant #{ant.id} at #{ant.row}, #{ant.col} continuing with existing goal"
    end

    if ant.route.nil?
      log "Ant has no route to goal"
      ant.route = ant.square.route_to(ant.goal.last)
    end

    # take the first step, unless it's off limits; then take a random step
    # TODO should be able to cache this route with the ant and have it remember its plan, only recompute if plan goes invalid
    next_step = if ant.route
                  ant.route.shift
                else
                  # This shouldn't happen (except in the test cases)
                  log "No route exists to goal! Map is:\n" + Square.dump_map(ant.square, ant.goal.last)
                  valid.rand
                end

    # Double-check validity of first step
    if !valid.member?(next_step)
      log "Can't execute route, next step is invalid. Clearing route and moving randomly"
      ant.route = nil
      next_step = valid.rand
    end

    log "Moving to #{next_step.row}, #{next_step.col}"
    off_limits.add(next_step)
    ant.order_to next_step
  end
end
