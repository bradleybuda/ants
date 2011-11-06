require 'singleton'

# abstract goals
class Goal
  CONCRETE_GOALS = [:Eat, :Raze, :Kill, :Defend, :Explore, :Escort, :Plug]

  @@matrix = nil

  def self.all
    CONCRETE_GOALS.inject([]) { |acc, klass| Module.const_get(klass).all + acc }
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

# TODO i think this is broken in the DFS for some reason
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
    "<Goal: defend #{@item} from #{@square}>"
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

  # TODO only one ant should attempt to execute the plug goal
  def self.all
    if Plug.active?
      Hill.all.find_all(&:mine?).map { |hill| Plug.new(hill) }
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
    Ant.living.find_all { |ant| Escort.ant_is_escortable?(ant)  }.map { |ant| Escort.new(ant) }
  end

  def self.ant_is_escortable?(ant)
    ant.alive? && ant.goal && ant.goal.valid? && CAN_ESCORT.any? { |goal| ant.goal.kind_of?(goal) }
  end

  def initialize(ant)
    super()
    @ant = ant
  end

  def valid?
    Escort.ant_is_escortable?(@ant)
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
