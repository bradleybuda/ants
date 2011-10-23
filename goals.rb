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
  end

  def valid?
    Square.at(@square.row, @square.col)
  end

  def distance2(square)
    square.distance2(@square)
  end

  def next_square(square)
    route = square.route_to(@square)
    (route.nil? || route.empty?) ? square : route.first
  end
end

class OwnHill < Destination
  def valid?
    super && @square.hill && @square.hill == 0
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

class Defend < OwnHill
  def self.all
    Square.all.find_all do |square|
      square.neighbors.any? do |neighbor|
        neighbor.hill && neighbor.hill == 0
      end
    end.map { |square| Defend.new(square) }
  end

  def to_s
    # TODO which hill?
    "<Goal: defend own hill near #{@square}>"
  end
end

class Plug < OwnHill
  @@plug_active = false

  def enable!
    @@plug_active = true
  end

  def disable!
    @@plug_active = false
  end

  def self.all
    if @@plug_active
      Square.all.find_all { |square| square.hill && square.hill == 0 }.map { |square| Plug.new(square) }
    else
      []
    end
  end

  def valid?
    @@plug_active && super
  end

  def to_s
    "<Goal: prevent spawning ants from own hill at #{@square}>"
  end
end

class Escort
  # TODO should probably also be able to chase defend
  CAN_ESCORT = [Eat, Explore, Raze, Kill]

  def self.all
    Ant.living.find_all { |ant| ant.goal && ant.goal.valid? && CAN_ESCORT.any? { |goal| ant.goal === goal } }.map { |ant| Escort.new(ant) }
  end

  def initialize(ant)
    @ant = ant
  end

  def valid?
    @ant.alive? && @ant.goal.valid? && CAN_ESCORT.any? { |goal| @ant.goal === goal }
  end

  def to_s
    "<Goal: escort #{@ant}>"
  end
end

class Wander
  include Singleton

  def self.all
    [Wander.instance]
  end

  def valid?
    true
  end

  def distance2(square)
    0.1 # wander is always nearby but non-zero
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
    when Escort then WEIGHTS['chase']
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
