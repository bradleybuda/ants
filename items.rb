# a non-moving item (hill or food)
class Item
  @@all = [] # TODO would this be faster as a Set?

  attr_reader :square

  def self.all
    @@all
  end

  def initialize(square)
    @square = square
    @square.item = self
    @observable_from = @square.visible_squares
    @@all << self

    sense!
  end

  def exists?
    @square.item == self
  end

  def sense!
    @last_seen = AI.instance.turn_number
  end

  def time_since_last_seen
    AI.instance.turn_number - @last_seen
  end

  def destroy_if_unsensed!
    # don't destroy if observed this turn
    return if time_since_last_seen.zero?

    # destroy if observable but not sensed
    if @observable_from.any? { |square| square.ant }
      log "#{self} has disappeared"
      @square.item = nil if exists?
      @@all.delete(self)
    end
  end
end

class Hill < Item
  def self.all
    Item.all.find_all { |i| i.kind_of?(Hill) }
  end

  def initialize(owner, square)
    super(square)
    @owner = owner
  end

  def mine?
    @owner == 0
  end

  def enemy?
    @owner != 0
  end

  def to_s
    "<#{mine? ? 'My' : 'Enemy'} hill at #{@square}, last seen #{time_since_last_seen} turns ago>"
  end
end

class Food < Item
  def self.all
    Item.all.find_all { |i| i.kind_of?(Food) }
  end

  def to_s
    "<Food at #{@square}, last seen #{time_since_last_seen} turns ago>"
  end
end

# a moving item, which has a somewhat different model
# we don't try to do any "motion tracking" on enemies - just assume they're all new each turn
class EnemyAnt < Item
  def self.all
    Item.all.find_all { |i| i.kind_of?(EnemyAnt) }
  end

  def initialize(owner, square)
    super(square)
    @owner = owner
  end

  def to_s
    "<Enemy ant at #{@square}, last seen #{time_since_last_seen} turns ago>"
  end
end

