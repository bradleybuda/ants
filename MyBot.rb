$:.unshift File.dirname($0)

require 'ai.rb'
require 'ant.rb'
require 'items.rb'
require 'stats.rb'
require 'params_matrix.rb'
require 'goals.rb'
require 'log.rb'
require 'square.rb'

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

AI.instance.setup do |ai|
  log "Mybot: Setup"
end

# wish this didn't have to be so conservative...
TIME_SELF_OUT = true
TIMEOUT_FUDGE = 0.5

AI.instance.run do |ai|
  budget = (ai.turntime / 1000.0) * TIMEOUT_FUDGE

  living = Ant.living

  # Update map visibility
  log "Updating visible squares for #{living.count} ants"
  updated = living.inject(0) { |total, ant| total + ant.square.visit! }
  log "Updated visibility of #{updated} squares"

  # Compute game statistics for weighting model
  stats = Stats.new(ai)
  Goal.stats = stats
  log "Current turn statistics are #{stats.inspect}"

  # Make a shared list of goals used by all ants
  # TODO can skip this until we actually need to pick a goal
  log "Looking for goals"
  goals = Goal.all
  goal_stats = goals.group_by(&:class).map { |k, v| [k, v.size] }
  log "Found #{goals.size} initial goals - #{goal_stats.inspect}"

  # Make a priority queue of ants to move
  ants_to_move = living.sort_by do |ant|
    # two-dimensional sort - first on the goal type, then on the priority
    if ant.goal.nil?
      [-1, nil]
    elsif ant.goal.class == Escort
      [1, ant.goal.priority]
    else
      [0, ant.goal.priority]
    end
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
    # TODO deduplicate this - square should have an unblocked_neighbors method or something
    valid = ant.square.neighbors - ant.square.blacklist
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
      ant.goal = Goal.pick(ant, goals)
    elsif !ant.goal.valid?
      log "#{ant} can no longer execute #{ant.goal}, picking a new one"
      ant.goal = Goal.pick(ant, goals)
    else
      log "#{ant} will continue with #{ant.goal}"
    end

    next_square = ant.goal.next_square(ant)
    log "#{ant} wants to go to #{next_square}"

    if next_square == ant.square
      log "#{ant} will stay put to execute #{ant.goal}"
    elsif valid.member?(next_square)
      log "#{ant} will move to #{next_square}"
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

  log "No more ants to move, done with turn"
  Plug.disable! # all ants moved within time budget, so allow spawning again
end
