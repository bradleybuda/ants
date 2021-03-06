$:.unshift File.dirname(__FILE__)
%w(ai ant containers items stats params_matrix goals log priority_queue search_node square timeout_loop).each { |lib| require lib }

module Enumerable
  def rand
    sort_by { Kernel.rand }.first
  end
end

AI.instance.setup do |ai|
  log "Mybot: Setup"
end

goal_search_queue = Containers::PriorityQueue.new

AI.instance.run do |ai|
  log "Search queue has size #{goal_search_queue.size} (from previous turns)"

  ants_to_move = Ant.living.dup

  # Update map visibility
  log "Updating visible squares for #{ants_to_move.count} ants"
  updated = ants_to_move.inject(0) { |total, ant| total + ant.square.visit! }
  log "Updated visibility of #{updated} squares"

  # TODO restore any newly visible squares to the goal_search_queue if
  # they were previously set aside

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

  # Purge all invalid ant goals
  # TODO can push this down to the second loop
  ants_to_move.each do |ant|
    if ant.goal && !ant.goal.valid?
      ant.goal = nil
    end
  end

  # Figure out which goals are new and seed them into the DFS queue
  goals.each do |goal|
    square = goal.square
    if !square.goals.has_key?(goal)
      goal_search_queue.push(SearchNode.new(goal.square, goal, []), 2)
    end
  end

  log "Search queue has size #{goal_search_queue.size} after goal generation"

  search_radius = 0; search_count = 0 # instrument how far we were able to search
  TimeoutLoop.run((AI.instance.turntime / 1000.0) * 0.5) do
    # visit the first node in the queue and unpack it
    node = goal_search_queue.pop
    if node.nil?
      log "BFS: No more squares to search"
      TimeoutLoop.halt!
      next
    end

    search_radius = node.route.size
    search_count += 1

    square = node.square
    goal = node.goal
    route = node.route

    # Purge from queue if no longer valid
    next unless goal.valid?

    # Record the route to this goal on the square
    square.goals[goal] = route

    # put neighboring squares at end of search queue
    square.neighbors.each do |neighbor|
      # TODO instead of skipping, need to put this on a retry queue
      next if !neighbor.observed?

      # Don't enqueue the neighbor if we've already visited it for this goal
      next if neighbor.goals.has_key?(goal)

      new_route = [square] + route
      goal_search_queue.push(SearchNode.new(neighbor, goal, new_route), 1.0 / new_route.size)
    end
  end

  # TODO restore the plug goal?

  log "BFS: done searching. Search count was #{search_count}, radius was at least #{search_radius - 1} squares from goals"

  # Issue orders for each ant's best-available goal
  TimeoutLoop.run((AI.instance.turntime / 1000.0) * 0.2) do
    ant = ants_to_move.shift
    if ant.nil?
      log "Issued orders to all ants before timing out"
      TimeoutLoop.halt!
      next
    end

    log "Next ant in queue is #{ant}; after this we have #{ants_to_move.size} to move."

    # Find the best goal that this square knows about and is passable
    square = ant.square
    passable = square.neighbors - square.blacklist

    # Iterate through all the square's goals doing two things: purge invalids, and find highest priority
    best_goal = Wander.instance
    best_route = Wander.pick_route_for_ant(ant)

    log "Square has #{square.goals.size} goals attached"

    square.goals.each do |goal, route|
      if goal.valid?
        if goal.priority > best_goal.priority && passable.member?(route.first)
          best_goal = goal
          best_route = route
        end
      else
        square.goals.delete(goal)
      end
    end

    log "Best passable goal from #{square} is #{best_goal} with route #{best_route}"
    ant.goal = best_goal # required for escortability check

    if best_route.empty?
      log "#{ant} has reached destination (or is stuck) and will not move"
    else
      log "#{ant} will move to #{best_route.first}"
      ant.order_to best_route.first
    end
  end
end
