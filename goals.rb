require 'psych'
require 'singleton'

WEIGHTS_FILE = ARGV[0] || 'weights.yml'
WEIGHTS = Psych.load(File.open(WEIGHTS_FILE, 'r'))

# TODO persist goals from turn-to-turn to make the all call less expensive?
# Create goals as data stream comes in (i.e. food and hills)

# abstract goals

class Destination
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

  def next_square(ant, valid_squares)
    return nil if ant.square == @square # arrived

    if (!@route_cache[ant] || !valid_squares.member?(@route_cache[ant].first))
      # we either don't have a route, or it's blocked, so reroute
      routes = valid_squares.map do |vs|
        route = vs.route_to(@square)
        route.nil? ? nil : [vs] + route
      end.compact

      if routes.empty?
        log "No route to destination"
        return nil
      end
      @route_cache[ant] = routes.min_by(&:length)
    end

    @route_cache[ant].shift
  end
end

# concrete goals

class Eat < Destination
  def self.all
    Square.all.find_all(&:has_food?).map { |square| Eat.new(square) }
  end

  def valid?
    super && @square.has_food?
  end

  def to_s
    "<Goal: eat food at #{@square}>"
  end
end

class Explore < Destination
  def self.all
    Square.all.find_all(&:frontier?).map { |square| Explore.new(square) }
  end

  def valid?
    super && !@square.observed?
  end

  def to_s
    "<Goal: explore #{@square}>"
  end
end

class Raze < Destination
  def self.all
    Square.all.find_all { |square| square.hill && square.hill != 0 }.map { |square| Raze.new(square) }
  end

  def valid?
    super && @square.hill && @square.hill != 0
  end

  def to_s
    "<Goal: raze enemy hill at #{@square}>"
  end
end

class Kill < Destination
  def self.all
    Square.all.find_all { |square| square.ant && square.ant.enemy? }.map { |square| Kill.new(square) }
  end

  def valid?
    super && @square.ant && @square.ant.owner != 0
  end

  def to_s
    "<Goal: kill enemy ant at #{@square}>"
  end
end

class Defend < Destination
  def self.all
    results = []

    Square.all.each do |square|
      if square.hill && square.hill == 0
        square.neighbors.each do |neighbor|
          results << Defend.new(neighbor, square)
        end
      end
    end

    results
  end

  def initialize(square, hill_square)
    super(square)
    @hill_square = hill_square
  end

  def valid?
    # TODO invalid if another ant is on the spot
    @hill_square.hill && @hill_square.hill == 0 && rand > 0.2 # don't defend too long
  end

  def to_s
    "<Goal: defend #{@hill_square} from #{@square}>"
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

class Escort
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

  def next_square(ant, valid_squares)
    # TODO factor out w/ Destination - this is very similar but a moving target
    # can't cache routes b/c target moves
    valid_squares.min_by { |vs| route = vs.route_to(@ant.square); route.nil? ? 1_000_000 : route.length }
  end

  def to_s
    "<Goal: escort #{@ant} executing #{@ant.goal}>"
  end
end

class Wander
  include Singleton

  def self.all
    [Wander.instance]
  end

  def valid?
    rand > 0.5 # don't wander too long
  end

  def distance2(square)
    0.1 # wander is always nearby but non-zero
  end

  def next_square(ant, valid_squares)
    # give wander a bias toward open space
    # not sure if this is a good policy or not
    valid_squares.max_by { |square| square.neighbors.count }
  end

  def to_s
    "<Goal: wander randomly>"
  end
end

# Manager class

class Goal
  NEARBY_THRESHOLD = 2_000
  CONCRETE_GOALS = [Eat, Raze, Kill, Defend, Explore, Escort, Plug, Wander]

  def self.all
    CONCRETE_GOALS.inject([]) { |acc, klass| klass.all + acc }
  end

  # TODO simplify
  # higher weights mean higher priorities
  def self.weight(ai, goal)
    case goal
    when Eat then WEIGHTS['eat'] / ai.my_ants.count
    when Raze then WEIGHTS['raze'] * ai.my_ants.count
    when Kill then WEIGHTS['kill'] * ai.my_ants.count
    when Defend then WEIGHTS['defend'] * ai.my_ants.count
    when Explore then WEIGHTS['explore']
    when Escort then WEIGHTS['escort'] * ai.my_ants.count
    when Plug then WEIGHTS['plug']
    when Wander then WEIGHTS['wander']
    end
  end

  def self.pick(ai, goals, ant)
    # pick a destination based on proximity and a weighting factor
    nearby_goals = goals.find_all { |goal| goal.distance2(ant.square) < NEARBY_THRESHOLD }
    goal = nearby_goals.max_by { |goal| weight(ai, goal) / Math.sqrt(goal.distance2(ant.square)) }
    log "Picked goal #{goal} for #{ant}"
    goal
  end
end
