require 'set'

# Represent a single field of the map. These fields are either land or
# unknown - once a square is observed as water, it is deleted
class Square
  @@rows = nil
  @@cols = nil
  @@index = nil

  @@observed = []

  # pretty-print map for debugging
  def self.dump_map(from, to)
    map = ""
    0.upto(@rows - 1) do |row|
      0.upto(@cols - 1) do |col|
        square = Square.at(row, col)

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

  # Build the full grid, assuming no water. As we discover water, squares will be deleted
  def self.create_squares(rows, cols, viewradius2)
    @@viewradius2 = viewradius2
    @@rows = rows
    @@cols = cols

    @@visibility_mask = []
    viewradius = Math.sqrt(@@viewradius2).ceil
    (-1 * viewradius).upto(viewradius).each do |row_offset|
      (-1 * viewradius).upto(viewradius).each do |col_offset|
        if distance2(0, 0, row_offset, col_offset) < @@viewradius2
          @@visibility_mask << [row_offset, col_offset]
        end
      end
    end

    @@index = Array.new(@@rows * @@cols) do |i|
      Square.new(i / @@cols, i % @@cols)
    end
  end

  def self.all
    @@index.compact
  end

  def self.observed
    @@observed
  end

  def self.reset!
    @@index.each { |square| square.reset! if square }
  end

  def self.at(row, col)
    @@index[position_to_index(row, col)]
  end

  def self.position_to_index(row, col)
    ((row % @@rows) * @@cols) + (col % @@cols)
  end

  attr_reader :row, :col
  attr_accessor :ant, :next_ant
  attr_accessor :item

  def initialize(row, col)
    @row = row
    @col = col
    @observed = false
    @visited = false
    @item = nil
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
      neighbor_row = @row + row_offset
      neighbor_col = @col + col_offset
      [direction, Square.at(neighbor_row, neighbor_col)]
    end

    actual_neighbors = possible_neighbors.reject { |direction, neighbor| neighbor.nil? }

    Hash[actual_neighbors]
  end

  def direction_to(destination)
    direction_to_neighbors.find { |direction, neighbor| neighbor == destination }.first
  end

  # Mark as visited and return the number of observed squares
  def visit!
    return 0 if @visited
    @visited = true

    visible_squares.inject(0) do |observed_count, vis|
      if vis.observed?
        observed_count # no change
      else
        vis.observe!
        observed_count + 1
      end
    end
  end

  def visited?
    @visited
  end

  def observed?
    @observed
  end

  def observe!
    @observed = true
    @@observed << self
  end

  def visible_squares
    @_visible_squares ||= @@visibility_mask.map do |row_offset, col_offset|
      Square.at(@row + row_offset, @col + col_offset)
    end.compact

    # Can't cache which ones are non-nil
    @_visible_squares.find_all { |s| Square.at(s.row, s.col) }
  end

  def visible(square)
    distance2(square) < @@viewradius2
  end

  def frontier?
    observed? && ! neighbors.all?(&:observed?)
  end

  def has_food?
    @item && @item.kind_of?(Food)
  end

  def has_hill?
    @item && @item.kind_of?(Hill)
  end

  def has_enemy_ant?
    @item && @item.kind_of?(EnemyAnt)
  end

  def destroy!
    neighbors.each do |neighbor|
      neighbor.remove_dead_neighbor(self)
    end

    @@index[Square.position_to_index(@row, @col)] = nil
    @@observed.delete(self)
  end

  def remove_dead_neighbor(dead_neighbor)
    direction = direction_to(dead_neighbor)
    @neighbors.delete(direction)
  end

  def self.distance2(r1, c1, r2, c2)
    rdelt = (r1 - r2).abs
    cdelt = (c1 - c2).abs
    dr = [rdelt, @@rows - rdelt].min
    dc = [cdelt, @@cols - cdelt].min
    (dr**2 + dc**2)
  end

  def distance2(other)
    Square.distance2(@row, @col, other.row, other.col)
  end

  def to_s
    "[#{@row}, #{@col}]"
  end

  def blacklist
    # TODO also blacklist friendly hills
    Set.new(neighbors.find_all { |n| n.next_ant || n.has_food? })
  end

  # A* from http://en.wikipedia.org/wiki/A*
  def route_to(goal)
    log "looking for route from #{self} to #{goal}"
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
    @next_ant = @ant = nil
  end
end
