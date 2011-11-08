require 'matrix'

class Stats
  def initialize(ai)
    total_space = (ai.rows * ai.cols).to_f

    non_water = observed = visited = food = my_ants = enemy_ants = my_hills = enemy_hills = 0.0

    # TODO don't loop over all squares
    Square.all.each do |square|
      non_water += 1
      observed += 1 if square.observed?
      visited += 1 if square.visited?
      food += 1 if square.has_food?
      enemy_hills += 1 if square.has_hill? && square.item.enemy?
      my_hills += 1 if square.has_hill? && square.item.mine?
      enemy_ants += 1 if square.has_enemy_ant?
    end

    my_ants = Ant.living.count

    # These are rates instead of ratios to avoid low-precision
    # floats. They're not intuitive - just statistics to be used by the
    # algorithm
    @water = total_space / (total_space - non_water)
    @observed = total_space / observed
    @visited = total_space / visited
    @food = total_space / (food + 1)
    @my_ants = total_space / (my_ants + 1)
    @enemy_ants = total_space / (enemy_ants + 1)
    @my_hills = total_space / (my_hills + 1)
    @enemy_hills = total_space / (enemy_hills + 1)
    # TODO enemy count
  end

  def to_vector
    Vector[@water, @observed, @visited, @food, @my_ants, @enemy_ants, @my_hills, @enemy_hills]
  end
end
