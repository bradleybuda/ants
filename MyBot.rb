$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'

require 'psych'
WEIGHTS_FILE = ARGV[0] || 'weights.yml'
WEIGHTS = Psych.load(File.open(WEIGHTS_FILE, 'r'))
LOOK_THRESHOLD = 2_000

# higher weights mean higher priorities
def weight(ai, type)
  case type
  when :food then WEIGHTS['food'] / ai.my_ants.count
  when :raze then WEIGHTS['raze'] * ai.my_ants.count
  when :kill then WEIGHTS['kill'] * ai.my_ants.count
  when :defend then WEIGHTS['defend'] * ai.my_ants.count
  when :explore then WEIGHTS['explore']
  when :chase then WEIGHTS['chase'] # TODO this would be better as "escort"
  when :plug then WEIGHTS['plug']
  when :random then 1.0
  end
end

def pick_goal(ai, destinations, ant)
  # pick a destination based on proximity and a weighting factor
  nearby_destinations = destinations.find_all { |_, square| ant.square.distance2(square) < LOOK_THRESHOLD }
  candidates = if nearby_destinations.empty?
                 log "No nearby destinations, will make a random move"
                 ant.square.neighbors.map { |neighbor| [:random, neighbor] }
               else
                 nearby_destinations
               end

  type, destination = candidates.min_by { |type, square| Math.sqrt(ant.square.distance2(square).to_f) / weight(ai, type) }
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
    destination.neighbors.any? { |neighbor| neighbor.hill && neighbor.hill == 0 }
  when :kill
    destination.ant && destination.ant.enemy?
  when :plug
    false # plug missions only last one turn?
  when :chase
    false # chase missions only last one turn
  end
end

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

# Once this is set, it will be maintained for the rest of the
# game. That wasn't my original intention, but it seems to work pretty
# well.
avoid_growth = false

ai = AI.new

ai.setup do |ai|
  log "Mybot: Setup"
end

ai.run do |ai|
  budget = (ai.turntime / 1000.0) * 0.8 # wish this didn't have to be so conservative...

  # Update map visibility
  log "Updating visible squares for #{ai.my_ants.count} ants"
  updated = ai.my_ants.inject(0) { |total, ant| total + ant.square.observe_visible_from_here! }
  log "Updated visibility of #{updated} squares"

  # Make a shared list of destinations used by all ants
  log "Looking for destinations"
  destinations = Square.all.map do |square|
    if square.has_food?
      [:food, square]
    elsif square.frontier?
      [:explore, square]
    elsif square.hill && square.hill != 0
      [:raze, square]
    elsif avoid_growth && square.hill && square.hill == 0
      [:plug, square]
    elsif square.neighbors.any? { |neighbor| neighbor.hill && neighbor.hill == 0 }
      [:defend, square]
    elsif square.ant && square.ant.enemy?
      [:kill, square]
    end
  end.compact
  destinations = [[:random, Square.all.rand]] if destinations.empty? # If there's absolutely nowhere to go
  log "Found #{destinations.size} initial destinations"

  # Keep track of ant positions
  # Pessimistically assume ants are staying put, but remove from this list if they move
  off_limits = Set.new
  ai.my_ants.each { |ant| off_limits.add(ant.square) }
  ai.my_hills.each { |square| off_limits.add(square) } unless avoid_growth

  # Make a queue of ants to move
  # Ideally, this might be a priority queue based on each ant's goal value
  ants_to_move = ai.my_ants.shuffle # jitter the move order so if we're running out of time, we don't always get the same ants stuck
  stuck_once = Set.new

  until ants_to_move.empty? do
    elapsed_time = Time.now.to_f - ai.start_time
    remaining_budget = budget - elapsed_time
    log "Spent #{(elapsed_time * 1000).to_i}/#{(budget * 1000).to_i}, #{(remaining_budget * 1000).to_i} remains"
    if remaining_budget <= 0
      log "Out of time, aborting with #{ants_to_move.size} unmoved ants. Will avoid spawning new ants."
      avoid_growth = true
      break
    end

    ant = ants_to_move.shift
    log "Next ant in queue is #{ant.id}. After this we have #{ants_to_move.size} to move."

    # delay orders if we're stuck
    valid = Set.new(ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) })
    if valid.empty?
      if stuck_once.member?(ant)
        log "Ant #{ant.id} at #{ant.row}, #{ant.col} is stuck again, abandoning"
      else
        log "Ant #{ant.id} at #{ant.row}, #{ant.col} is stuck, delaying orders until later"
        ants_to_move.push(ant)
        stuck_once.add(ant)
      end

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
      log "Ant has no route to goal - rerouting"
      ant.route = ant.square.route_to(ant.goal.last)
    end

    # take the first step, unless it's off limits; then take a random step
    # TODO should be able to cache this route with the ant and have it remember its plan, only recompute if plan goes invalid
    next_step = if ant.route
                  # Ant has a valid goal and route - make it chaseable (if it's not chasing)
                  goal_type = ant.goal.first
                  if goal_type != :chase && goal_type != :defend && goal_type != :random
                    log "Adding #{ant.id} as a chase target"
                    destinations << [:chase, ant.square]
                  end

                  ant.route.shift
                else
                  # This shouldn't happen (except in the test cases)
                  log "No route exists to goal! Map is:\n" + Square.dump_map(ant.square, ant.goal.last)
                  valid.first
                end

    # Double-check validity of first step
    if !valid.member?(next_step)
      log "Can't execute route, next step is invalid. Clearing route and goal and moving randomly"
      ant.goal  = nil
      ant.route = nil
      next_step = valid.first
    end

    log "Moving to #{next_step.row}, #{next_step.col}"
    off_limits.delete(ant.square) unless ant.square.hill == 0
    off_limits.add(next_step)
    ant.order_to next_step
  end
end
