#!/usr/bin/env ruby

require 'active_support/core_ext'
require 'open3'
require './params_matrix.rb'

class Chromosome
  BYTE_LENGTH = 64
  MAX_TURNS = 1_000

  attr_reader :data

  def initialize(matrix = nil)
    @matrix = matrix || begin
                          file = "/tmp/matrix-#{rand(100_000_000)}"
                          `dd if=/dev/urandom of=#{file} bs=#{BYTE_LENGTH} count=1 2> /dev/null`
                          ParamsMatrix.read(File.open(file))
                        end
    @_fitness = {}
  end

  def fitness(player_seed, engine_seed, maps)
    # Score is unweighted average share of total available
    # points. This normalizes difference between maps that have
    # different numbers of available points.
    scores = []
    maps.each do |map|
      my_score, opponent_score, turns = calculate_fitness(player_seed, engine_seed, map)

      scores << my_score.to_f / (my_score + opponent_score)
    end

    # higher is better
    puts scores.inspect
    scores.inject(&:+) / scores.size
  end

  # Fitness is memoized across generations. If we vary the fitness
  # function over time, need to revisit this.
  def calculate_fitness(player_seed, engine_seed, map)
    @_fitness[[player_seed, engine_seed, map]] ||= calculate_fitness!(player_seed, engine_seed, map)
  end

  def calculate_fitness!(player_seed, engine_seed, map)
    playgame = "/Users/brad/src/ants-tools/playgame.py"
    ruby = "/Users/brad/.rvm/rubies/ruby-1.9.2-p180/bin/ruby"
    bot = File.expand_path(File.dirname(__FILE__)) + "/MyBot.rb"
    data_file = "/tmp/matrix_#{rand(100_000_000)}"
    log_dir = "#{data_file}_logs"
    html = "#{log_dir}/game.html"
    opponent = "python /Users/brad/src/ants-tools/sample_bots/python/HunterBot.py"

    ParamsMatrix.write(File.open(data_file, 'w'), @matrix)

    cmd = "#{playgame} -R -S -I -O -E --html=#{html} --log_dir #{log_dir} --player_seed #{player_seed} --engine_seed #{engine_seed} --fill --verbose --nolaunch --turns #{MAX_TURNS} --map_file #{map} '#{ruby} #{bot} #{data_file}' '#{opponent}'"
    STDERR.puts "Running: #{cmd}"
    out, err, status = Open3.capture3(cmd)
    STDERR.puts "Status: #{status}"
    STDERR.puts "Erorrs:\n\n#{err}" unless err.empty?
    raise "Failed to run #{cmd}" unless status.success?

    out =~ /^score (\d+) (\d+)$/
    my_score = $1.to_i
    opponent_score = $2.to_i
    out =~ /^playerturns (\d+)/
    turns = $1.to_i

    result = [my_score, opponent_score, turns]
    puts result.inspect
    result
  end

  def mutation
    s = bits_as_string

    # Pick a random byte and bit within that byte to mutate
    byte_idx = rand(BYTE_LENGTH * 8)
    s[byte_idx] = (s[byte_idx] == "0") ? "1" : "0"

    raw = [bits_as_string].pack("B*")
    buffer = StringIO.new(raw)
    matrix = ParamsMatrix.read(buffer)
    Chromosome.new(matrix)
  end

  def crossover(other)
    # will crossover immediately to the left of this character index
    crossover_point = rand(BYTE_LENGTH * 8 - 1) + 1

    [[self, other], [other, self]].map do |mom, dad|
      mom_bits = mom.bits_as_string
      dad_bits = dad.bits_as_string

      bits_as_string = mom_bits[0, crossover_point] + dad_bits[crossover_point, BYTE_LENGTH * 8]

      # TODO duplicate code
      raw = [bits_as_string].pack("B*")
      buffer = StringIO.new(raw)
      matrix = ParamsMatrix.read(buffer)
      Chromosome.new(matrix)
    end
  end

  def bits_as_string
    buffer = StringIO.new
    ParamsMatrix.write(buffer, @matrix)
    s = buffer.string
    s.force_encoding("ASCII-8BIT")
    s.unpack("B*").first
  end
end

# main
if __FILE__ == $0
  generation = 0
  population = Array.new(10) { Chromosome.new }
  ARGV.each { |file| population.unshift Chromosome.new(ParamsMatrix.new(File.open(file))) }

  # play 1-1 vs a CPU on every 2-player map and see how we do
  maps = Dir["/Users/brad/src/ants-tools/maps/**/*_02p_*.map"]

  loop do
    player_seed = rand(1_000_000)
    engine_seed = rand(1_000_000)

    puts "Starting generation #{generation} with population #{population.size}"

    # force each chromosome to compute fitness in parallel
    work_queue = []
    population.each { |c| maps.each { |m| work_queue << [c, m] } }
    mutex = Mutex.new

    workers = Array.new(4) do |i|
      Thread.new do
        loop do
          sleep(rand * 2) # jitter to make log output cleaner
          item = nil
          mutex.synchronize { item = work_queue.shift }
          break unless item

          STDERR.puts "[#{i}] Working on #{item}"
          chromosome, map = item
          chromosome.calculate_fitness(player_seed, engine_seed, map) # callee will cache this
        end

        STDERR.puts "[#{i}] Done working"
      end
    end

    workers.each(&:join)

    # Join the results
    ranked = population.sort_by { |c| c.fitness(player_seed, engine_seed, maps) }.reverse
    puts "Fitness scores: #{ranked.map { |c| c.fitness(player_seed, engine_seed, maps) }.inspect}"

    # Save the winner
    ParamsMatrix.write(File.open("best-#{Process.pid}-#{generation}", "w"), ranked.first.matrix)

    generation += 1

    # Create new generation from elite, mutants, crossovers, and randoms
    new_population = [
                      ranked.first,
                      ranked.first.mutation,
                      ranked.second.mutation.mutation,
                      ranked.second.mutation.mutation.mutation,
                    ]
    ranked.first(6).each_slice(2) do |mom, dad|
      kids = mom.crossover(dad)
      new_population += kids
    end

    new_population += Array.new(2) { Chromosome.new }
    population = new_population
  end
end
