#!/usr/bin/env ruby

require 'ai4r'
require 'psych'

DEFAULTS = Psych.load(File.open('weights.yml', 'r'))

class AntChromosome
  @@all = []
  @@lock = Mutex.new
  @@ran_tournaments = false

  def self.run_tournaments_if_necessary!
    @@lock.synchronize do
      return if @@ran_tournaments

      # pick a game size of 2-10 players
      game_size = rand(9) + 2
      STDERR.puts "Will play #{game_size} player games"

      # generate round-robin games until everyone has played an equal number
      player_order = @@all.sort_by { rand }
      to_play = player_order.dup

      until to_play.empty? do
        to_play += player_order.dup if to_play.size < game_size

        next_game = to_play.shift(game_size)
        play_game(next_game)
      end

      @@ran_tournaments = true # TODO when does this reset?
    end
  end

  def self.play_game(players)
    STDERR.puts "Playing a game"
    # TODO
  end

  attr_reader :params

  # Ai4r hooks
  attr_accessor :normalized_fitness

  def self.seed
    chromosome = AntChromosome.new(DEFAULTS)
    self.mutate(chromosome)
    return chromosome
  end

  def self.reproduce(a, b)
    # buggy fucking library
    a = a.first if a.kind_of? Array
    b = b.first if b.kind_of? Array

    keys = a.params.keys
    k1, k2 = keys.partition { rand < 0.5 }

    child_params = {}

    k1.each { |key| child_params[key] = a.params[key] }
    k2.each { |key| child_params[key] = b.params[key] }

    AntChromosome.new(child_params)
  end

  def self.mutate(chromosome)
    if chromosome.normalized_fitness && rand < ((1 - chromosome.normalized_fitness) * 0.3)
      key = chromosome.params.keys.min_by { rand }
      old_value = chromosome.params[key]
      new_value = 2**(rand * 2 - 1) * old_value
      chromosome.params[key] = new_value

      @fitness = nil
    end
  end

  def initialize(params)
    @params = params
  end

  def fitness
    # play a 1-1 vs a CPU and see how we do
    File.open('/tmp/ant-params.yml', 'w') { |f| f.write(Psych.dump(@params)) }

    max_turns = 1_000
    cmd = "/Users/brad/src/ants-tools/playgame.py --verbose --nolaunch --turns #{max_turns} --map_file /Users/brad/src/ants-tools/maps/maze/maze_02p_01.map '/Users/brad/.rvm/rubies/ruby-1.9.2-p180/bin/ruby /Users/brad/src/ants/MyBot.rb /tmp/ant-params.yml' 'python /Users/brad/src/ants-tools/sample_bots/python/HunterBot.py'"
    #puts cmd
    result = `#{cmd}`

    result =~ /^score (\d+) (\d+)$/
    my_score = $1.to_i
    opponent_score = $2.to_i

    result =~ /^playerturns (\d+)/
    turns = $1.to_i

    fitness = (my_score - opponent_score).to_f / turns.to_f
    STDERR.puts [fitness, my_score, opponent_score, turns].inspect

    fitness
  end
end

Ai4r::GeneticAlgorithm::Chromosome = AntChromosome



#population = Array.new(10) { AntParameters.new(defaults) }

search = Ai4r::GeneticAlgorithm::GeneticSearch.new(10, 20)
result = search.run

p result
