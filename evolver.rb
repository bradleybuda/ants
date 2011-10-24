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

  def fitness
    data.write(File.open('/tmp/matrix', 'w'))

    # play a 1-1 vs a CPU and see how we do
    max_turns = 5
    cmd = "/Users/brad/src/ants-tools/playgame.py --verbose --nolaunch --turns #{max_turns} --map_file /Users/brad/src/ants-tools/maps/maze/maze_02p_01.map '/Users/brad/.rvm/rubies/ruby-1.9.2-p180/bin/ruby /Users/brad/src/ants/MyBot.rb /tmp/matrix' 'python /Users/brad/src/ants-tools/sample_bots/python/HunterBot.py'"
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

  def mutation
    raw = bits

    # Pick a random byte and bit within that byte to mutate
    byte_idx = rand(BYTE_LENGTH)
    bit_mask = [0b00000001, 0b00000010, 0b00000100, 0b00001000, 0b00010000, 0b00100000, 0b01000000, 0b10000000][rand(8)]
    raw.setbyte(byte_idx, raw.getbyte(byte_idx) ^ bit_mask)

    mutated_buffer = StringIO.new(raw)
    mutated_data = ParamsMatrix.new(mutated_buffer)
    Chromosome.new(mutated_data)
  end

  def crossover(other)
    # will crossover immediately to the left of this character index
    crossover_point = rand(BYTE_LENGTH * 8 - 1) + 1

    [[self, other], [other, self]].map do |mom, dad|
      mom_bits = mom.bits_as_string
      dad_bits = dad.bits_as_string

      bits_as_string = mom_bits[0, crossover_point] + dad_bits[crossover_point, BYTE_LENGTH * 8]
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
  population = Array.new(10) { Chromosome.new }
  generation = 0

  loop do
    ranked = population.sort_by(&:fitness)

    # Save the winner
    ranked.first.data.write(File.open("best-#{generation}", "w"))

    # Each generation is made up of:
    # 1 elite
    # 1 mutant elite
    # 6 offsping of the top 6 elements
    # 2 new contenders
    new_population = [ranked.first, ranked.first.mutation]
    ranked.first(6).each_slice(2) do |mom, dad|
      kids = mom.crossover(dad)
      new_population += kids
    end
    new_population += Array.new(2) { Chromosome.new }

    population = new_population
    generation += 1
  end
end
