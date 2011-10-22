$:.unshift File.dirname($0)
require 'ants.rb'

require 'set'
VISITED_SQUARES = Set.new

ai = AI.new

ai.setup do |ai|
  STDERR.puts "Mybot: Setup"
end

ai.run do |ai|
  ai.my_ants.each do |ant|
    # mark current square visited
    VISITED_SQUARES.add ant.square.coords

    # find valid moves
    valid = [:N, :E, :S, :W].find_all do |dir|
      ant.square.neighbor(dir).land?
    end

    # find unexplored
    unexplored = valid.reject do |dir|
      coords = ant.square.neighbor(dir).coords
      VISITED_SQUARES.include?(coords)
    end

    ant.order unexplored.first || valid.first unless valid.empty? #TODO huh?
  end
end
