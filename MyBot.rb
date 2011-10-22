$:.unshift File.dirname($0)
require 'ants.rb'

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

  # These lists are useful to all ants
  squares = Square.all
  food = squares.find_all(&:has_food?)
  log "I know about #{food.size} food"
  unobserved = squares.reject(&:observed?)
  log "There are #{unobserved.size} never-visited squares"

  ai.my_ants.each do |ant|
    log "Where should ant at #{ant.row}, #{ant.col} go?"

    # make sure we're not stuck
    valid = ant.square.neighbors.reject { |neighbor| off_limits.include?(neighbor) }
    next if valid.empty? # stay put

    # TODO maybe don't use line-of-sight for these next two...

    # is there any food?
    target = food.sort_by { |uo| ant.square.distance2(uo) }.first
    log "chasing food" if target

    # is there anything unexplored?
    if target.nil?
      target = unobserved.sort_by { |uo| ant.square.distance2(uo) }.first
      log "exploring" if target
    end

    # no food and whole map observed? really?
    if target.nil?
      target = squares.rand
      log "nothing to do"
    end

    log "Target is #{target.row}, #{target.col}"

    # take the first step, unless it's off limits; then take a random step
    route = ant.square.route_to(target)
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
