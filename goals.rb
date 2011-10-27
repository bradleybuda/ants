require 'singleton'

# abstract goals
class Goal
  NEARBY_THRESHOLD = 200
  CONCRETE_GOALS = [:Eat, :Raze, :Kill, :Defend, :Explore, :Escort, :Plug, :Wander]
  MATRIX = ParamsMatrix.new(File.open(ARGV[0] || 'matrix'))

  def self.all
    CONCRETE_GOALS.inject([]) { |acc, klass| Module.const_get(klass).all + acc }
  end

  def self.stats=(stats)
    @@stats = stats
    @@priorities = Hash[CONCRETE_GOALS.zip(MATRIX.to_priorities(stats.to_a))]
  end

  def self.pick(ant, goals)
    # pick a destination based on proximity and a weighting factor
    nearby_goals = goals.find_all { |goal| goal.distance2(ant.square) < NEARBY_THRESHOLD }
    goal = nearby_goals.min_by(&:priority)
    log "Picked goal #{goal} for #{ant} from among #{nearby_goals.count} nearby goal(s)"
    goal
  end

  def priority
    @@priorities[self.class.to_s.to_sym]
  end
end

class Destination < Goal
  def initialize(square)
    @square = square
    @route_cache = {} # ant => route
  end

  def valid?
    Square.at(@square.row, @square.col)
  end

  def distance2(square)
    square.distance2(@square) + 0.1 # prevent zero distance, which can cause ants to get stuck
  end

  def next_square(ant)
    return nil if ant.square == @square # arrived

    if (!@route_cache[ant] || ant.square.blacklist.member?(@route_cache[ant].first) || has_water?(@route_cache[ant]))
      log "Generating new route for #{ant} to #{@square} (cache missing or invalid)"

      route = ant.square.route_to(@square)

      if route.nil?
        log "No route to destination"
        return nil
      end

      @route_cache[ant] = route
    end

    @route_cache[ant].shift
  end

  def has_water?(route)
    route.any? { |square| Square.at(square.row, square.col).nil? }
  end
end

class NextToItem < Destination
  def initialize(destination, item)
    super(destination)
    @item = item
  end

  def valid?
    @item.exists?
  end
end

# concrete goals

class Explore < Destination
  def self.all
    Square.observed.find_all { |square| square.frontier? }.map { |square| Explore.new(square) }
  end

  def valid?
    super && !@square.visited?
  end

  def to_s
    "<Goal: explore #{@square}>"
  end
end

class Raze < Destination
  def self.all
    Hill.all.find_all(&:enemy?).map { |hill| Raze.new(hill) }
  end

  def initialize(hill)
    super(hill.square)
    @hill = hill
  end

  def valid?
    @hill.exists?
  end

  def to_s
    "<Goal: raze #{@hill}>"
  end
end

class Kill < Destination
  def self.all
    Square.all.find_all { |square| square.enemy_ant }.map { |square| Kill.new(square) }
  end

  def valid?
    super && @square.enemy_ant
  end

  def to_s
    "<Goal: kill enemy ant at #{@square}>"
  end
end

class Defend < NextToItem
  def self.all
    results = []

    Hill.all.find_all(&:mine?).each do |hill|
      hill.square.neighbors.each do |neighbor|
        results << Defend.new(neighbor, hill)
      end
    end

    results
  end

  def to_s
    "<Goal: defend #{@point_of_interest} from #{@square}>"
  end
end

class Eat < NextToItem
  def self.all
    results = []

    Food.all.each do |food|
      food.square.neighbors.each do |neighbor|
        results << Eat.new(neighbor, food)
      end
    end

    results
  end

  def to_s
    "<Goal: eat food at #{@point_of_interest} from #{@square}>"
  end
end

class Plug < Destination
  @@plug_active = false

  def self.enable!
    @@plug_active = true
  end

  def self.disable!
    @@plug_active = false
  end

  def self.active?
    @@plug_active
  end

  # TODO only one ant should attempt to execute the plug goal
  def self.all
    if @@plug_active
      Square.all.find_all { |square| square.hill && square.hill == 0 }.map { |square| Plug.new(square) }
    else
      []
    end
  end

  def valid?
    # TODO invalid if another ant is on the spot
    @@plug_active && @square.hill && @square.hill == 0
  end

  def to_s
    "<Goal: prevent spawning ants from own hill at #{@square}>"
  end
end

class Escort < Goal
  # TODO should probably also be able to chase defend
  CAN_ESCORT = [Eat, Explore, Raze, Kill]

  def self.all
    Ant.living.find_all { |ant| ant.goal && ant.goal.valid? && CAN_ESCORT.any? { |goal| ant.goal.kind_of?(goal) } }.map { |ant| Escort.new(ant) }
  end

  def initialize(ant)
    @ant = ant
  end

  def valid?
    @ant.alive? && @ant.goal.valid? && CAN_ESCORT.any? { |goal| @ant.goal === goal }
  end

  def distance2(square)
    @ant.square.distance2(square)
  end

  def next_square(ant)
    # TODO factor out w/ Destination - this is very similar but a moving target
    # can't cache routes b/c target moves
    route = ant.square.route_to(@ant.square)
    route.nil? ? nil : route.first
  end

  def to_s
    "<Goal: escort #{@ant} executing #{@ant.goal}>"
  end
end

class Wander < Goal
  include Singleton

  def self.all
    [Wander.instance]
  end

  def valid?
    rand > 0.5 # don't wander too long
  end

  def distance2(square)
    1.0 # put in a little anti-wander bias
  end

  def next_square(ant)
    valid_squares = ant.square.neighbors - ant.square.blacklist

    # give wander a bias toward open space
    # not sure if this is a good policy or not
    valid_squares.max_by { |square| square.neighbors.count * rand }
  end

  def to_s
    "<Goal: wander randomly>"
  end
end
