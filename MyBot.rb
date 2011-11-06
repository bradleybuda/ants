$:.unshift File.dirname(__FILE__)
%w(ai ant items stats params_matrix goals log square timeout_loop).each { |lib| require lib }

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

AI.instance.setup do |ai|
  log "Mybot: Setup"
end

AI.instance.run do |ai|
  ants_to_move = Ant.living.dup

  # Update map visibility
  log "Updating visible squares for #{ants_to_move.count} ants"
  updated = ants_to_move.inject(0) { |total, ant| total + ant.square.visit! }
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

  # Purge any invalid goals
  ants_to_move.each do |ant|
    ant.goal = Wander.instance unless ant.goal.valid?
  end

  # Breadth-first search from all goals
  visited = Set.new
  queue = goals.map { |goal| { :square => goal.square, :goal => goal, :route => [] } }
  TimeoutLoop.run((AI.instance.turntime / 1000.0) * 0.7) do
    # visit the first node in the queue and unpack it
    elt = queue.shift
    if elt.nil?
      log "BFS: No more squares to search"
      TimeoutLoop.halt!
      next
    end

    square = elt[:square]
    goal = elt[:goal]
    route = elt[:route]

    visited << [goal, square]

    # Adjust ant orders if necessary
    if ant = square.ant
      log "BFS: hit #{ant} with #{goal}"
      if ant.goal.nil?
        log "BFS: #{ant} had no goal, assigning it this one"
        ant.goal = goal # TODO assign route as well
      else
        log "BFS: #{ant} already has #{ant.goal}, comparing priorities"
        if ant.goal.priority < goal.priority
          log "BFS: new #{goal} is higher priority, giving it to #{ant}"
          ant.goal = goal
        else
          log "BFS: existing #{ant.goal} is higher priority, no change to goal"
        end
      end
    end

    # put neighboring squares at end of search queue
    square.neighbors.each do |neighbor|
      next if visited.member?([goal, neighbor])
      queue.push({ :square => neighbor, :goal => goal, :route => [square] + route })
    end
  end

  # Issue orders for each ant's best-available goal
  stuck_once = []
  TimeoutLoop.run((AI.instance.turntime / 1000.0) * 0.1) do
    ant = ants_to_move.shift
    if ant.nil?
      log "Issued orders to all ants before timing out"
      TimeoutLoop.halt!
      next
    end

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

    log "#{ant} wants to #{ant.goal} and has valid moves to #{valid.to_a}"
    next_square = ant.goal.next_square(ant) # TODO use precomputed route

    log "#{ant} wants to go to #{next_square}"

    if next_square == ant.square
      log "#{ant} will stay put to execute #{ant.goal}"
    elsif valid.member?(next_square)
      log "#{ant} will move to #{next_square}"
      ant.order_to next_square
    else
      log "#{ant} is stuck, delaying orders until later"
      ants_to_move.push(ant)
      stuck_once << ant
    end
  end
end
