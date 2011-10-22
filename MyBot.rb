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
  start_time = Time.now.to_f
  budget = (ai.turntime / 1000.0) * 0.9

  # Update map visibility
  log "Updating visible squares"
  ai.my_ants.each { |ant| ant.square.observe_visible_from_here! }

  # Make a shared list of destinations used by all ants
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
  destinations = [[:random, Square.all.rand]] if destinations.empty? # If there's absolutely nowhere to go
  log "Found #{destinations.size} possible destinations"

  # Keep track of ant positions
  # Pessimistically assume ants are staying put, but remove from this list if they move
  off_limits = Set.new
  ai.my_ants.each { |ant| off_limits.add(ant.square) }

  # Make a queue of ants to move
  # Ideally, this might be a priority queue based on each ant's goal value
  ants_to_move = ai.my_ants.shuffle # jitter the move order so if we're running out of time, we don't always get the same ants stuck

  until ants_to_move.empty? || ((Time.now.to_f - start_time) > budget) do
    ant = ants_to_move.shift
    log "Next ant in queue is #{ant.id}. After this we have #{ants_to_move.map(&:id)} to move."

    # delay orders if we're stuck
    valid = ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    if valid.empty?
      log "Ant #{ant.id} at #{ant.row}, #{ant.col} is stuck, delaying orders"
      ants_to_move.push(ant)
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
    off_limits.delete(ant.square)
    off_limits.add(next_step)
    ant.order_to next_step
  end
end
