#!/usr/bin/env ruby

require './params_matrix.rb'

class Chromosome
  BYTE_LENGTH = 256

  attr_reader :data

  def initialize(data = nil)
    @data = data || begin
                      `dd if=/dev/urandom of=/tmp/matrix bs=#{BYTE_LENGTH} count=1 2> /dev/null`
                      ParamsMatrix.new(File.open('/tmp/matrix'))
                    end
  end

  # Fitness is memoized across generations. If we vary the fitness
  # function over time, need to revisit this.
  def fitness
    @_fitness ||= calculate_fitness
  end

  def calculate_fitness
    playgame = "/Users/brad/src/ants-tools/playgame.py"
    ruby = "/Users/brad/.rvm/rubies/ruby-1.9.2-p180/bin/ruby"
    bot = File.expand_path(File.dirname(__FILE__)) + "/MyBot.rb"
    data_file = '/tmp/matrix'
    max_turns = 300
    opponent = "python /Users/brad/src/ants-tools/sample_bots/python/HunterBot.py"

    data.write(File.open(data_file, 'w'))

    # play 1-1 vs a CPU on every 2-player map and see how we do
    maps = Dir["/Users/brad/src/ants-tools/maps/**/*_02p_*.map"]

    net_score = 0
    total_turns = 0

    maps.each do |map|
      cmd = "#{playgame} --fill --verbose --nolaunch --turns #{max_turns} --map_file #{map} '#{ruby} #{bot} #{data_file}' '#{opponent}'"
      result = `#{cmd}`
      STDERR.puts result

      result =~ /^score (\d+) (\d+)$/
      my_score = $1.to_i
      opponent_score = $2.to_i

      net_score += (my_score - opponent_score)

      result =~ /^playerturns (\d+)/
      turns = $1.to_i

      total_turns += turns
    end

    # higher is better
    fitness = [net_score, 1.0 / total_turns]
    puts fitness.inspect

    fitness
  end

  def mutation
    s = bits_as_string

    # Pick a random byte and bit within that byte to mutate
    byte_idx = rand(BYTE_LENGTH * 8)
    s[byte_idx] = (s[byte_idx] == "0") ? "1" : "0"

    raw = [bits_as_string].pack("B*")
    buffer = StringIO.new(raw)
    data = ParamsMatrix.new(buffer)
    Chromosome.new(data)
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
      data = ParamsMatrix.new(buffer)
      Chromosome.new(data)
    end
  end

  def bits_as_string
    buffer = StringIO.new
    data.write(buffer)
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

  loop do
    puts "Starting generation #{generation} with population #{population.size}"

    ranked = population.sort_by(&:fitness).reverse
    puts "Fitness scores: #{ranked.map(&:fitness).inspect}"

    # Save the winner
    ranked.first.data.write(File.open("best-#{Process.pid}-#{generation}", "w"))

    generation += 1

    # Each generation is made up of:
    # 1 elite
    # 1 mutant elite
    # 6 offsping of the top 6 elements
    # 2 new contenders
    #
    # TODO higher initial mutation rate (since initial population is so uniform?)
    new_population = [ranked.first, ranked.first.mutation]
    ranked.first(6).each_slice(2) do |mom, dad|
      kids = mom.crossover(dad)
      new_population += kids
    end

    new_population += Array.new(2) { Chromosome.new }
    population = new_population
  end
end
