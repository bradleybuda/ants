# Represents a single friendly ant. Enemy ants don't get a class
class Ant
  @@living = []
  @@next_ant_id = 0

  attr_accessor :id
  attr_accessor :square
  attr_accessor :next_square
  attr_accessor :goal
  attr_accessor :alive

  def initialize(square)
    @square = @next_square = square
    link_squares_to_me!

    @id = @@next_ant_id
    @@next_ant_id += 1

    @@living << self
  end

  # TODO do this when dead
  def clear_square_links!
    @square.ant = nil
    @next_square.next_ant = nil
  end

  def link_squares_to_me!
    @square.ant = self
    @next_square.next_ant = self
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
    clear_square_links!
  end

  # TODO can I combine this somehow with order_to?
  def advance_turn!
    clear_square_links!
    @square = @next_square
    link_squares_to_me!
  end

  # Order this ant to go to a given *adjacent* square and note the next expected position.
  def order_to(adjacent)
    clear_square_links!
    @next_square = adjacent
    link_squares_to_me!

    AI.instance.order(square, square.direction_to(adjacent))
  end

  def to_s
    "<Ant #{@id} at #{@square}>"
  end
end
