# Represents a single friendly ant. Enemy ants don't get a class
# TODO could we gain anything by having Ant subclass Item?
class Ant
  @@living = []
  @@next_ant_id = 0

  attr_reader :square
  attr_reader :next_square
  attr_accessor :id
  attr_accessor :goal
  attr_accessor :route

  def initialize(square)
    @square = @next_square = square
    @square.ant = self
    @square.next_ant = self
    @route = []

    @id = @@next_ant_id
    @@next_ant_id += 1

    @@living << self
  end

  def self.living
    @@living
  end

  def self.advance_turn!
    self.living.each(&:advance_turn!)
  end

  def alive?
    @@living.member?(self)
  end

  def die!
    @@living.delete(self)
    @square = @next_square = nil
  end

  # Entering this method, all squares should have @ant == nil
  def advance_turn!
    @square = @next_square
    @square.ant = @square.next_ant = self
  end

  # Order this ant to go to a given *adjacent* square and note the next expected position.
  def order_to(adjacent)
    @next_square = adjacent
    @next_square.next_ant = self

    AI.instance.order(square, square.direction_to(adjacent))
  end

  def to_s
    "<Ant #{@id} at #{@square}>"
  end
end
