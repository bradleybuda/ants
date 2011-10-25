require 'set'

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

    Square.create_squares(@rows, @cols)
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
      _, name, value = *rd.match(/\A([a-z0-9_]+) (-?\d+)\Z/)

      case name
      when 'loadtime'; @loadtime=value.to_i
      when 'turntime'; @turntime=value.to_i
      when 'rows'; @rows=value.to_i
      when 'cols'; @cols=value.to_i
      when 'turns'; @turns=value.to_i
      when 'viewradius2'; @viewradius2=value.to_i
      when 'attackradius2'; @attackradius2=value.to_i
      when 'spawnradius2'; @spawnradius2=value.to_i
      when 'player_seed'; @seed=value.to_i; srand(@seed);
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
