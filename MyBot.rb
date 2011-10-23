$:.unshift File.dirname($0)
require 'ants.rb'
require 'goals.rb'

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

ai.run do |ai|
  budget = (ai.turntime / 1000.0) * 0.8 # wish this didn't have to be so conservative...

  # Update map visibility
  log "Updating visible squares for #{ai.my_ants.count} ants"
  updated = ai.my_ants.inject(0) { |total, ant| total + ant.square.observe_visible_from_here! }
  log "Updated visibility of #{updated} squares"

  # Make a shared list of goals used by all ants
  # TODO can skip this until we actually need to pick a goal
  log "Looking for goals"
  goals = Goal.all
  log "Found #{goals.size} initial goals"

  # Keep track of ant positions
  # Pessimistically assume ants are staying put, but remove from this list if they move
  off_limits = Set.new
  ai.my_ants.each { |ant| off_limits.add(ant.square) }
  ai.my_hills.each { |square| off_limits.add(square) } unless Plug.active?

  # Make a queue of ants to move
  # Ideally, this might be a priority queue based on each ant's goal value

  # escorting ants go to the back of the line, so they don't get in the way of their escort targets
  ants_to_move = ai.my_ants.sort_by do |ant|
    ant.goal.kind_of?(Escort) ? 1 : -1
  end

  stuck_once = Set.new

  until ants_to_move.empty? do
    elapsed_time = Time.now.to_f - ai.start_time
    remaining_budget = budget - elapsed_time
    log "Spent #{(elapsed_time * 1000).to_i}/#{(budget * 1000).to_i}, #{(remaining_budget * 1000).to_i} remains"
    if remaining_budget <= 0
      log "Out of time, aborting with #{ants_to_move.size} unmoved ants. Will avoid spawning new ants."
      Plug.enable! # TODO disable plug goal if time goes back down
      break
    end

    ant = ants_to_move.shift
    log "Next ant in queue is #{ant}. After this we have #{ants_to_move.size} to move."

    # delay orders if we're stuck
    valid = Set.new(ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) })
    # TODO i don't think we need this code, we have the same logic below
    if valid.empty?
      if stuck_once.member?(ant)
        log "#{ant} is stuck again, abandoning"
      else
        log "#{ant} is stuck, delaying orders until later"
        ants_to_move.push(ant)
        stuck_once.add(ant)
      end

      next
    end

    if ant.goal.nil?
      log "#{ant} has no goal, needs a new one"
      ant.goal = Goal.pick(ai, goals, ant)
    elsif !ant.goal.valid?
      log "#{ant} can no longer execute #{ant.goal}, picking a new one"
      ant.goal = Goal.pick(ai, goals, ant)
    else
      log "#{ant} will continue with #{ant.goal}"
    end

    # As of now, +next_square+ isn't *required* to use the valid list,
    # it's just a hint. It's still the caller's job to ensure valid
    # moves are made
    next_square = ant.goal.next_square(ant.square, valid)
    if next_square == ant.square
      log "#{ant} will stay put to execute #{ant.goal}"
    elsif valid.member?(next_square)
      log "#{ant} will move to #{next_square}"
      off_limits.delete(ant.square) unless ant.square.hill == 0
      off_limits.add(next_square)
      ant.order_to next_square
    else
      if stuck_once.member?(ant)
        log "#{ant} is stuck again, issuing no orders"
      else
        log "#{ant} is stuck, delaying orders until later"
        ants_to_move.push(ant)
        stuck_once.add(ant)
      end
    end
  end
end
