# Represents a single ant.
class Ant
  # Owner of this ant. If it's 0, it's your ant.
  attr_accessor :owner
  # Square this ant sits on.
  attr_accessor :square

  attr_accessor :alive, :ai

  def initialize alive, owner, square, ai
    @alive, @owner, @square, @ai = alive, owner, square, ai
  end

  # True if ant is alive.
  def alive?; @alive; end
  # True if ant is not alive.
  def dead?; !@alive; end

  # Equivalent to ant.owner==0.
  def mine?; owner==0; end
  # Equivalent to ant.owner!=0.
  def enemy?; owner!=0; end

  # Returns the row of square this ant is standing at.
  def row; @square.row; end
  # Returns the column of square this ant is standing at.
  def col; @square.col; end

  # Order this ant to go in given direction. Equivalent to ai.order ant, direction.
  def order direction
    @ai.order self, direction
  end
end

# Represent a single field of the map. These fields are either land or
# unknown - once a square is observed as water, it is deleted
class Square
  @@index = nil

  def self.create_squares(rows, cols)
    @@index = Array.new(rows) do |row|
      Array.new(cols) do |col|
        Square.new(row, col)
      end
    end
  end

  def self.rows
    @@index.size
  end

  def self.cols
    @@index.first.size
  end

  def self.reset!
    @@index.each { |row| row.each { |square| square.reset! if square } }
  end

  def self.at(row, col)
    @@index[row][col]
  end

  attr_reader :row, :col
  attr_accessor :hill, :food, :ant

  def initialize(row, col)
    @row = row
    @col = col
    @observed = false
  end

  def neighbors
    @neighbors ||= make_neighbors
    @neighbors.values
  end

  def direction_to_neighbors
    @neighbors ||= make_neighbors
  end

  def make_neighbors
    possible_neighbors = [[:e, 0, 1], [:w, 0, -1], [:s, 1, 0], [:n, -1, 0]].map do |direction, row_offset, col_offset|
      neighbor_row = (@row + row_offset) % Square.rows
      neighbor_col = (@col + col_offset) % Square.cols
      [direction, Square.at(neighbor_row, neighbor_col)]
    end

    actual_neighbors = possible_neighbors.reject { |direction, neighbor| neighbor.nil? }

    Hash[actual_neighbors]
  end

  def direction_to(destination)
    direction_to_neighbors.find { |direction, neighbor| neighbor == destination }.first
  end

  def observe!
    @observed = true
  end

  def observed?
    @observed
  end

  def destroy!
    neighbors.each do |neighbor|
      neighbor.remove_dead_neighbor(self)
    end

    @@index[@row][@col] = nil
  end

  def remove_dead_neighbor(dead_neighbor)
    direction = direction_to(dead_neighbor)
    @neighbors.delete(direction)
  end

  def coords
    [@row, @col]
  end

  def reset!
    @food = @hill = false
    @ant = nil
  end
end

class AI
  # Map, as an array of arrays.
  attr_accessor :map
  # Number of current turn. If it's 0, we're in setup turn. If it's :game_over, you don't need to give any orders; instead, you can find out the number of players and their scores in this game.
  attr_accessor	:turn_number

  # Game settings. Integers.
  attr_accessor :loadtime, :turntime, :rows, :cols, :turns, :viewradius2, :attackradius2, :spawnradius2, :seed
  # Radii, unsquared. Floats.
  attr_accessor :viewradius, :attackradius, :spawnradius

  # Number of players. Available only after game's over.
  attr_accessor :players
  # Array of scores of players (you are player 0). Available only after game's over.
  attr_accessor :score

  # Initialize a new AI object. Arguments are streams this AI will read from and write to.
  def initialize stdin=$stdin, stdout=$stdout
    @stdin, @stdout = stdin, stdout

    @map=nil
    @turn_number=0

    @my_ants=[]
    @enemy_ants=[]

    @did_setup=false
  end

  # Returns a read-only hash of all settings.
  def settings
    {
      :loadtime => @loadtime,
      :turntime => @turntime,
      :rows => @rows,
      :cols => @cols,
      :turns => @turns,
      :viewradius2 => @viewradius2,
      :attackradius2 => @attackradius2,
      :spawnradius2 => @spawnradius2,
      :viewradius => @viewradius,
      :attackradius => @attackradius,
      :spawnradius => @spawnradius,
      :seed => @seed
    }.freeze
  end

  # Zero-turn logic.
  def setup # :yields: self
    read_intro
    yield self

    @stdout.puts 'go'
    @stdout.flush

    Square.create_squares(@rows, @cols)
    @did_setup=true
  end

  # Turn logic. If setup wasn't yet called, it will call it (and yield the block in it once).
  def run &b # :yields: self
    setup &b if !@did_setup

    over=false
    until over
      over = read_turn
      yield self

      @stdout.puts 'go'
      @stdout.flush
    end
  end

  # Internal; reads zero-turn input (game settings).
  def read_intro
    rd=@stdin.gets.strip
    warn "unexpected: #{rd}" unless rd=='turn 0'

    until((rd=@stdin.gets.strip)=='ready')
      _, name, value = *rd.match(/\A([a-z0-9]+) (\d+)\Z/)

      case name
      when 'loadtime'; @loadtime=value.to_i
      when 'turntime'; @turntime=value.to_i
      when 'rows'; @rows=value.to_i
      when 'cols'; @cols=value.to_i
      when 'turns'; @turns=value.to_i
      when 'viewradius2'; @viewradius2=value.to_i
      when 'attackradius2'; @attackradius2=value.to_i
      when 'spawnradius2'; @spawnradius2=value.to_i
      when 'seed'; @seed=value.to_i
      else
        warn "unexpected: #{rd}"
      end
    end

    STDERR.puts "loadtime: #{@loadtime}"
    STDERR.puts "rows: #{@rows}"
    STDERR.puts "cols: #{@cols}"

    @viewradius=Math.sqrt @viewradius2
    @attackradius=Math.sqrt @attackradius2
    @spawnradius=Math.sqrt @spawnradius2
  end

  # Internal; reads turn input (map state).
  def read_turn
    ret=false
    rd=@stdin.gets.strip

    if rd=='end'
      @turn_number=:game_over

      rd=@stdin.gets.strip
      _, players = *rd.match(/\Aplayers (\d+)\Z/)
      @players = players.to_i

      rd=@stdin.gets.strip
      _, score = *rd.match(/\Ascore (\d+(?: \d+)+)\Z/)
      @score = score.split(' ').map{|s| s.to_i}

      ret=true
    else
      _, num = *rd.match(/\Aturn (\d+)\Z/)
      @turn_number=num.to_i
    end

    # reset the map data
    Square.reset!

    @my_ants=[]
    @enemy_ants=[]

    until((rd=@stdin.gets.strip)=='go')
      _, type, row, col, owner = *rd.match(/(w|f|h|a|d) (\d+) (\d+)(?: (\d+)|)/)
      row, col = row.to_i, col.to_i
      owner = owner.to_i if owner

      square = Square.at(row, col)

      case type
      when 'w'
        square.destroy!
      when 'f'
        square.food = true
      when 'h'
        square.hill = owner
      when 'a'
        a=Ant.new true, owner, Square.at(row, col), self
        square.ant = a

        if owner==0
          my_ants.push a
        else
          enemy_ants.push a
        end
      when 'd'
        d=Ant.new false, owner, Square.at(row, col), self
        square.ant = d
      when 'r'
        # pass
      else
        warn "unexpected: #{rd}"
      end
    end

    return ret
  end



  # call-seq:
  #   order(ant, direction)
  #   order(row, col, direction)
  #
  # Give orders to an ant, or to whatever happens to be in the given square (and it better be an ant).
  def order a, b, c=nil
    if !c # assume two-argument form: ant, direction
      ant, direction = a, b
      @stdout.puts "o #{ant.row} #{ant.col} #{direction.to_s.upcase}"
    else # assume three-argument form: row, col, direction
      col, row, direction = a, b, c
      @stdout.puts "o #{row} #{col} #{direction.to_s.upcase}"
    end
  end




  # Returns an array of your alive ants on the gamefield.
  def my_ants; @my_ants; end
  # Returns an array of alive enemy ants on the gamefield.
  def enemy_ants; @enemy_ants; end

  # If row or col are greater than or equal map width/height, makes them fit the map.
  #
  # Handles negative values correctly (it may return a negative value, but always one that is a correct index).
  #
  # Returns [row, col].
  def normalize row, col
    [row % @rows, col % @cols]
  end
end
