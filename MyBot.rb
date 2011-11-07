$:.unshift File.dirname(__FILE__)
%w(ai ant items stats params_matrix goals log search_node square timeout_loop).each { |lib| require lib }

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

  # Purge all previous goals
  # TODO cache routes and goals
  ants_to_move.each do |ant|
    if ant.goal && !ant.goal.valid?
      ant.goal = nil
      ant.route = []
    end
  end

  # Breadth-first search from all goals
  visited = Set.new
  queue = goals.map { |goal| SearchNode.new(goal.square, goal, []) }
  search_radius = 0; search_count = 0 # instrument how far we were able to search

  TimeoutLoop.run((AI.instance.turntime / 1000.0) * 0.8) do
    # visit the first node in the queue and unpack it
    node = queue.shift
    if node.nil?
      log "BFS: No more squares to search"
      TimeoutLoop.halt!
      next
    end

    search_radius = node.route.size
    search_count += 1

    # TODO keep the marker on the square instead of in the master set?
    visited << [node.goal, node.square]

    # Adjust ant orders if necessary
    if ant = node.square.ant
      log "BFS: hit #{ant} with #{node.goal}"
      if ant.goal.nil?
        log "BFS: #{ant} had no goal, assigning it this one"
        ant.goal = node.goal
        ant.route = node.route
      else
        log "BFS: #{ant} already has #{ant.goal}, comparing priorities"
        if ant.goal.priority < node.goal.priority
          log "BFS: new #{node.goal} is higher priority, giving it to #{ant}"
          ant.goal = node.goal
          ant.route = node.route
        else
          log "BFS: existing #{ant.goal} is higher priority, no change to goal"
        end
      end
    end

    # put neighboring squares at end of search queue
    node.square.neighbors.each do |neighbor|
      # I don't know if this is a good idea, to avoid searching never-observed squares
      next if !neighbor.observed?
      next if visited.member?([node.goal, neighbor])
      queue.push(SearchNode.new(neighbor, node.goal, [node.square] + node.route))
    end
  end

  log "BFS: done searching. Search count was #{search_count}, radius was at least #{search_radius - 1} squares from goals"

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

    route = ant.route
    valid = ant.square.neighbors - ant.square.blacklist

    if route.empty?
      log "#{ant} will stay put to execute #{ant.goal}"
    elsif valid.member?(route.first)
      log "#{ant} will move to #{route.first}"
      ant.order_to route.shift
    else
      log "#{ant} is stuck, delaying orders until later"
      ants_to_move.push(ant)
      stuck_once << ant
    end
  end
end
