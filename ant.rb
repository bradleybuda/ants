# Represents a single friendly ant. Enemy ants don't get a class
class Ant
  @@all = []
  @@next_ant_id = 0

  attr_accessor :id
  attr_accessor :square
  attr_accessor :next_square
  attr_accessor :goal
  attr_accessor :alive

  def initialize(square, alive)
    @square = @next_square = square
    link_squares_to_me!
    @alive = alive

    @id = @@next_ant_id
    @@next_ant_id += 1

    @@all << self
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

  def self.all
    @@all
  end

  def self.living
    @@all.find_all(&:alive?)
  end

  def self.advance_turn!
    self.all.each(&:advance_turn!)
  end

  # TODO can I combine this somehow with order_to?
  def advance_turn!
    clear_square_links!
    @square = @next_square
    link_squares_to_me!
  end

  def alive?; @alive; end
  def dead?; !@alive; end

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
