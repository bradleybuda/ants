require 'singleton'

# abstract goals
class Goal
  # TODO restore Plug
  CONCRETE_GOALS = [:Eat, :Raze, :Kill, :Defend, :Explore, :Escort, :Plug, :Wander]

  @@matrix = nil

  def self.all
    (CONCRETE_GOALS - [:Wander]).inject([]) { |acc, klass| Module.const_get(klass).all + acc }
  end

  def self.load_matrix!
    matrix_arg = ARGV[0] || 'matrix'
    @@matrix = if File.exists?(matrix_arg)
                 ParamsMatrix.read(File.open(matrix_arg))
               else
                 ParamsMatrix.from_base64(matrix_arg)
               end
  end

  def self.stats=(stats)
    load_matrix! unless @@matrix

    @@stats = stats
    @@priorities = Hash[CONCRETE_GOALS.zip(@@matrix * stats.to_vector)]
    log "Priorities for this round are #{@@priorities.inspect}"
  end

  def priority
    @@priorities[self.class.to_s.to_sym]
  end
end

# TODO combine these classes?
class Destination < Goal
  attr_reader :square

  def initialize(square)
    @square = square
  end

  def valid?
    Square.at(@square.row, @square.col)
  end

  def distance2(square)
    square.distance2(@square)
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
  @@index = {}

  def self.all
    Square.observed.find_all { |square| square.frontier? }.map do |square|
      @@index[square] ||= Explore.new(square)
    end
  end

  def valid?
    super && !@square.visited?
  end

  def to_s
    "<Goal: explore #{@square}>"
  end
end

class Raze < Destination
  @@index = {}

  def self.all
    Hill.all.find_all(&:enemy?).map do |hill|
      @@index[hill] ||= Raze.new(hill)
    end
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
    EnemyAnt.all.map { |enemy_ant| Kill.new(enemy_ant) }
  end

  def initialize(enemy_ant)
    super(enemy_ant.square)
    @enemy_ant = enemy_ant
  end

  def valid?
    @enemy_ant.exists?
  end

  def to_s
    "<Goal: kill #{@enemy_ant}>"
  end
end

class Defend < NextToItem
  @@index = {}

  def self.all
    results = []

    Hill.all.find_all(&:mine?).each do |hill|
      hill.square.neighbors.each do |neighbor|
        @@index[[neighbor, hill]] ||= Defend.new(neighbor, hill)
        results << @@index[[neighbor, hill]]
      end
    end

    results
  end

  def to_s
    "<Goal: defend #{@item} from #{@square}>"
  end
end

class Eat < NextToItem
  @@index = {}

  def self.all
    results = []

    Food.all.each do |food|
      food.square.neighbors.each do |neighbor|
        @@index[[neighbor, food]] ||= Eat.new(neighbor, food)
        results << @@index[[neighbor, food]]
      end
    end

    results
  end

  def to_s
    "<Goal: eat #{@item} from #{@square}>"
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

  @@index = {}

  def self.all
    if Plug.active?
      Hill.all.find_all(&:mine?).map do |hill|
        @@index[hill] ||= Plug.new(hill)
      end
    else
      []
    end
  end

  def initialize(hill)
    super(hill.square)
    @hill = hill
  end

  def valid?
    # TODO invalid if another ant is on the spot
    @@plug_active && @hill.exists?
  end

  def to_s
    "<Goal: prevent spawning ants at #{@hill}>"
  end
end

class Escort < Goal
  # TODO should probably also be able to chase defend
  CAN_ESCORT = [Eat, Explore, Raze, Kill]

  def self.all
    Ant.living.find_all { |ant| Escort.ant_is_escortable?(ant) }.map { |ant| Escort.new(ant) }
  end

  def self.ant_is_escortable?(ant)
    ant.alive? && ant.goal && ant.goal.valid? && CAN_ESCORT.any? { |goal| ant.goal.kind_of?(goal) }
  end

  def initialize(ant)
    @ant = ant
    @turn = AI.instance.turn_number
  end

  def valid?
    (AI.instance.turn_number == @turn) && Escort.ant_is_escortable?(@ant)
  end

  def distance2(square)
    @ant.square.distance2(square)
  end

  # TODO pull me up
  def square
    @ant.square
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

# pseudo-goal - it's the default when an ant has nothing to do
class Wander < Goal
  include Singleton

  def valid?
    false # only lasts one turn
  end

  def self.pick_route_for_ant(ant)
    valid = ant.square.neighbors - ant.square.blacklist
    random_square = valid.max_by { |square| square.neighbors.count * rand }
    random_square.nil? ? [] : [random_square]
  end

  def to_s
    "<Goal: wander randomly>"
  end
end
