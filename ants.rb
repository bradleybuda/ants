require 'set'

LOG = false
$last_log = Time.now.to_f
def log(s)
  if LOG
    now = Time.now.to_f
    interval = ((now - $last_log) * 1000).to_i
    $last_log = now
    File.open("log.#{Process.pid}", 'a+') { |f| f.puts("[%.3f] [+%03d] %s" % [now, interval, s]) }
  end
end

# Represents a single ant.
class Ant
  @@my_living_ants = {}
  @@next_ant_id = 0

  # Owner of this ant. If it's 0, it's your ant.
  attr_accessor :owner, :id
  # Square this ant sits on.
  attr_accessor :square, :next_square
  attr_accessor :alive, :ai
  attr_accessor :goal

  def initialize(alive, owner, square, ai)
    @alive, @owner, @square, @ai = alive, owner, square, ai

    if @owner == 0
      # assign an ID
      @id = @@next_ant_id
      @@next_ant_id += 1

      # keep track of current and next locations
      @@my_living_ants[@square] = self
      @next_square = @square
    end
  end

  def self.at(square)
    @@my_living_ants[square]
  end

  def self.living
    @@my_living_ants.values
  end

  def self.advance_all!
    last_locations = @@my_living_ants
    @@my_living_ants = {}
    last_locations.values.each do |ant|
      next if ant.dead?

      @@my_living_ants[ant.next_square] = ant

      # update current and next squares
      ant.square = ant.next_square
      ant.next_square = ant.square
    end
  end

  # True if ant is alive.
  def alive?; @alive; end
  # True if ant is not alive.
  def dead?; !@alive; end

  # Equivalent to ant.owner==0.
  def mine?; owner==0; end
  # Equivalent to ant.owner!=0.
  def enemy?; owner!=0; end

  # Order this ant to go to a given *adjacent* square and note the next expected position.
  def order_to(adjacent)
    @next_square = adjacent
    @ai.order self.square, square.direction_to(adjacent)
  end

  def to_s
    # TODO dead or alive?
    "<Ant #{@id} at #{@square}>"
  end
end

# Represent a single field of the map. These fields are either land or
# unknown - once a square is observed as water, it is deleted
class Square
  @@index = nil

  def self.dump_map(from, to)
    map = ""
    @@index.each do |row|
      row.each do |square|
        c = if square.nil?
              'X'
            elsif square == from
              '*'
            elsif square == to
              '$'
            elsif square.observed?
              '_'
            else
              ' '
            end
        map += c
      end
      map += "\n"
    end

    map
  end

  def self.create_squares(ai, rows, cols)
    @@index = Array.new(rows) do |row|
      Array.new(cols) do |col|
        Square.new(ai, row, col)
      end
    end
  end

  def self.all
    @@index.flatten.compact
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

  def initialize(ai, row, col)
    @ai = ai
    @row = row
    @col = col
    @observed = false
    @already_observed_from_here = false
  end

  def neighbors
    @neighbors ||= make_neighbors
    Set.new(@neighbors.values)
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

  def visit!
    return 0 if @already_observed_from_here == true
    vis = visible_squares.reject(&:observed?)
    vis.each(&:observe!)
    @visited = true
    return vis.size
  end

  def visited?
    @visited
  end

  def observed?
    @observed
  end

  def observe!
    @observed = true
  end

  def visible_squares
    @_visibles_squares ||= Square.all.find_all { |square| visible(square) }
  end

  def visible(square)
    distance2(square) < @ai.viewradius2
  end

  def frontier?
    !neighbors.all?(&:observed?)
  end

  def has_food?
    @food
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

  def distance2(other)
    dr = [(@row - other.row).abs, Square.rows - (@row - other.row).abs].min
    dc = [(@col - other.col).abs, Square.cols - (@col - other.col).abs].min
    (dr**2 + dc**2)
  end

  def to_s
    "[#{@row}, #{@col}]"
  end

  # A* from http://en.wikipedia.org/wiki/A*
  def route_to(goal, blacklist)
    log "looking for route from #{self} to #{goal} avoiding #{blacklist.to_a}"
    return nil if blacklist.member?(goal)

    closed_set = Set.new
    open_set = Set.new([self])
    came_from = {}

    g_score = {self => 0}
    h_score = {self => Math.sqrt(self.distance2(goal))}
    f_score = {self => g_score[self] + h_score[self]}

    until open_set.empty? do
      x = open_set.sort_by { |o| f_score[o] }.first

      if x == goal
        path = reconstruct_path(came_from, goal)
        path.shift
        log "found path #{path.map { |s| [s.row, s.col] }}"
        return path
      end

      open_set.delete(x)
      closed_set.add(x)

      (x.neighbors - blacklist).each do |y|
        next if closed_set.member?(y)

        tentative_g_score = g_score[x] + 1
        tentative_is_better = nil
        if !open_set.member?(y)
          open_set.add(y)
          tentative_is_better = true
        elsif tentative_g_score < g_score[y]
          tentative_is_better = true
        else
          tentative_is_better = false
        end

        if tentative_is_better
          came_from[y] = x
          g_score[y] = tentative_g_score
          h_score[y] = Math.sqrt(y.distance2(goal))
          f_score[y] = g_score[y] + h_score[y]
        end
      end
    end

    return nil # this should not ever happen, but it seems to occur with the test data
  end

  def reconstruct_path(came_from, current_node)
    if came_from[current_node]
      reconstruct_path(came_from, came_from[current_node]) + [current_node]
    else
      [current_node]
    end
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

  attr_accessor :my_ants, :my_hills, :enemy_ants

  attr_reader :start_time

  # Initialize a new AI object. Arguments are streams this AI will read from and write to.
  def initialize stdin=$stdin, stdout=$stdout
    @stdin, @stdout = stdin, stdout

    @map = nil
    @turn_number = 0

    @my_hills = []
    @my_ants = []
    @enemy_ants = []

    @did_setup = false
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

    Square.create_squares(self, @rows, @cols)
    @did_setup = true
  end

  # Turn logic. If setup wasn't yet called, it will call it (and yield the block in it once).
  def run &b # :yields: self
    setup &b if !@did_setup

    over=false
    until over
      GC.disable

      over = read_turn

      yield self

      @stdout.puts 'go'
      @stdout.flush

      GC.enable
      GC.start
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

    ##log "loadtime: #{@loadtime}"
    ##log "rows: #{@rows}"
    ##log "cols: #{@cols}"

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
      log "Starting turn #{@turn_number}"
      @start_time = Time.now.to_f
    end

    # reset the map data
    Square.reset!
    log "Reset map data"

    # update the expected position of each ant
    Ant.advance_all!
    log "Advanced all ant positions"

    @my_hils = []
    @my_ants = []
    @enemy_ants = []

    until((rd=@stdin.gets.strip)=='go')
      _, type, row, col, owner = *rd.match(/(w|f|h|a|d) (\d+) (\d+)(?: (\d+)|)/)
      row, col = row.to_i, col.to_i
      owner = owner.to_i if owner

      square = Square.at(row, col)

      case type
      when 'w'
        square.destroy!
      when 'f'
        log "food at #{square.row}, #{square.col}"
        square.food = true
      when 'h'
        square.hill = owner
        my_hills.push square if owner == 0
      when 'a', 'd'
        alive = (type == 'a')

        if owner == 0
          ant = Ant.at(square)
          # TODO destroy dead ants

          if ant.nil?
            if square.hill != 0
              log "no record of my ant at #{square.row}, #{square.col} - this is a bug. will resurrect"
            end

            ant = Ant.new(alive, 0, square, self)
            log "new ant has id #{ant.id}"
          else
            log "rediscovered ant #{ant.id} at #{square.row}, #{square.col}"
          end

          my_ants.push ant if alive
        else
          # we don't try to remember enemy ants
          ant = Ant.new(alive, owner, square, self)
          enemy_ants.push ant
        end
      when 'r'
        # pass
      else
        warn "unexpected: #{rd}"
      end
    end

    log "Got go! signal from game"

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
      log "Moving #{direction}"
      @stdout.puts "o #{ant.row} #{ant.col} #{direction.to_s.upcase}"
    else # assume three-argument form: row, col, direction
      col, row, direction = a, b, c
      log "Moving #{direction}"
      @stdout.puts "o #{row} #{col} #{direction.to_s.upcase}"
    end
  end

  # If row or col are greater than or equal map width/height, makes them fit the map.
  #
  # Handles negative values correctly (it may return a negative value, but always one that is a correct index).
  #
  # Returns [row, col].
  def normalize row, col
    [row % @rows, col % @cols]
  end
end
