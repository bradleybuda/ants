$:.unshift File.dirname($0)

require 'ants.rb'
require 'stats.rb'
require 'params_matrix.rb'
require 'goals.rb'
require 'log.rb'
require 'square.rb'

require 'set'

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

ai = AI.new

ai.setup do |ai|
  log "Mybot: Setup"
end

# wish this didn't have to be so conservative...
TIME_SELF_OUT = true
TIMEOUT_FUDGE = 0.5

ai.run do |ai|
  budget = (ai.turntime / 1000.0) * TIMEOUT_FUDGE

  # Update map visibility
  log "Updating visible squares for #{ai.my_ants.count} ants"
  updated = ai.my_ants.inject(0) { |total, ant| total + ant.square.visit!(ai.viewradius2) }
  log "Updated visibility of #{updated} squares"

  # Compute game statistics for weighting model
  stats = Stats.new(ai)
  log "Current turn statistics are #{stats.inspect}"

  # Make a shared list of goals used by all ants
  # TODO can skip this until we actually need to pick a goal
  log "Looking for goals"
  goals = Goal.all
  goal_stats = goals.group_by(&:class).map { |k, v| [k, v.size] }
  log "Found #{goals.size} initial goals - #{goal_stats.inspect}"

  # Keep track of ant positions
  # Pessimistically assume ants are staying put, but remove from this list if they move
  off_limits = Set.new
  ai.my_ants.each { |ant| off_limits << ant.square }
  ai.my_hills.each { |square| off_limits << square } unless Plug.active?

  # Make a queue of ants to move
  # Ideally, this might be a priority queue based on each ant's goal value

  # escorting ants go to the back of the line, so they don't get in the way of their escort targets
  ants_to_move = ai.my_ants.sort_by do |ant|
    ant.goal.kind_of?(Escort) ? 1 : -1
  end

  stuck_once = []

  until ants_to_move.empty? do
    elapsed_time = Time.now.to_f - ai.start_time
    remaining_budget = budget - elapsed_time
    log "Spent #{(elapsed_time * 1000).to_i}/#{(budget * 1000).to_i}, #{(remaining_budget * 1000).to_i} remains"
    if TIME_SELF_OUT && remaining_budget <= 0
      log "Out of time, aborting with #{ants_to_move.size} unmoved ants. Will avoid spawning new ants."
      Plug.enable!
      break
    end

    ant = ants_to_move.shift
    log "Next ant in queue is #{ant}. After this we have #{ants_to_move.size} to move."

    # delay orders if we're stuck
    # TODO i don't think we need this code, we have the same logic below
    valid = ant.square.neighbors - off_limits
    if valid.empty?
      if stuck_once.member?(ant)
        log "#{ant} is stuck again, abandoning"
      else
        log "#{ant} is stuck, delaying orders until later"
        ants_to_move.push(ant)
        stuck_once << ant
      end

      next
    end

    log "#{ant} has valid moves to #{valid.to_a}"

    if ant.goal.nil?
      log "#{ant} has no goal, needs a new one"
      ant.goal = Goal.pick(stats, goals, ant)
    elsif !ant.goal.valid?
      log "#{ant} can no longer execute #{ant.goal}, picking a new one"
      ant.goal = Goal.pick(stats, goals, ant)
    else
      log "#{ant} will continue with #{ant.goal}"
    end

    route_blacklist = ant.square.neighbors & off_limits
    next_square = ant.goal.next_square(ant, route_blacklist)
    log "#{ant} wants to go to #{next_square}"

    if next_square == ant.square
      log "#{ant} will stay put to execute #{ant.goal}"
    elsif valid.member?(next_square)
      log "#{ant} will move to #{next_square}"
      off_limits.delete(ant.square) unless ant.square.hill == 0
      off_limits << next_square
      ant.order_to next_square
    else
      # this should never happen right?
      if stuck_once.member?(ant)
        log "#{ant} is stuck again, telling it to spread out"
        ant.goal = Wander.instance
      else
        log "#{ant} is stuck, delaying orders until later"
        ants_to_move.push(ant)
        stuck_once << ant
      end
    end
  end

  Plug.disable! # all ants moved within time budget, so allow spawning again
end
