#!/usr/bin/env ruby

require 'active_support/core_ext'
require 'aws/s3'
require 'digest/sha1'
require 'elasticity'
require 'open3'
require './params_matrix.rb'

class Chromosome
  BYTE_LENGTH = 64
  MAX_TURNS = 1_000
  TURNTIME = 2_000

  attr_reader :matrix
  attr_accessor :fitness

  def initialize(matrix = nil)
    @matrix = matrix || begin
                          file = "/tmp/matrix-#{rand(100_000_000)}"
                          `dd if=/dev/urandom of=#{file} bs=#{BYTE_LENGTH} count=1 2> /dev/null`
                          ParamsMatrix.read(File.open(file))
                        end
  end

  def data
    ParamsMatrix.to_base64(@matrix)
  end

  def fitness_command(treeish, player_seed, engine_seed, map)
    home      = "/home/hadoop"
    python    = "/opt/Python-2.7.2/bin/python"
    tools     = "/opt/aichallenge/ants"
    ruby      = "/opt/ruby-1.9.2-p0/bin/ruby"
    scorefile = "/tmp/score-#{rand(100_000_000)}"

    [
     "cd #{home}/ants",
     "git checkout master",
     "git pull --rebase",
     "git checkout #{treeish}",
     "#{python} #{tools}/playgame.py --player_seed #{player_seed} --engine_seed #{engine_seed} --turns #{MAX_TURNS} --turntime #{TURNTIME} --fill --verbose -e --map_file #{tools}/maps/#{map} \"#{ruby} #{home}/ants/MyBot.rb '#{data}'\" \"#{python} #{tools}/dist/sample_bots/python/GreedyBot.py\" | grep -E '^score' > #{scorefile}",
     "echo '#{data}' `git rev-parse HEAD` #{player_seed} #{engine_seed} #{map} `cat #{scorefile}`",
    ].join(' && ')
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

INITIAL_POPULATION = 20
MAPS = %w(maze/maze_02p_01.map maze/maze_02p_02.map maze/maze_03p_01.map maze/maze_04p_01.map maze/maze_04p_02.map maze/maze_05p_01.map maze/maze_06p_01.map maze/maze_07p_01.map maze/maze_08p_01.map multi_hill_maze/maze_02p_01.map multi_hill_maze/maze_02p_02.map multi_hill_maze/maze_03p_01.map multi_hill_maze/maze_04p_01.map multi_hill_maze/maze_04p_02.map multi_hill_maze/maze_05p_01.map multi_hill_maze/maze_07p_01.map multi_hill_maze/maze_08p_01.map random_walk/random_walk_02p_01.map random_walk/random_walk_02p_02.map random_walk/random_walk_03p_01.map random_walk/random_walk_03p_02.map random_walk/random_walk_04p_01.map random_walk/random_walk_04p_02.map random_walk/random_walk_05p_01.map random_walk/random_walk_05p_02.map random_walk/random_walk_06p_01.map random_walk/random_walk_06p_02.map random_walk/random_walk_07p_01.map random_walk/random_walk_07p_02.map random_walk/random_walk_08p_01.map random_walk/random_walk_08p_02.map random_walk/random_walk_09p_01.map random_walk/random_walk_09p_02.map random_walk/random_walk_10p_01.map random_walk/random_walk_10p_02.map)
BUCKET = 'ant-chromosomes'

# Scale up
# instance_group_config = { :instance_count => 30, :instance_role => "TASK", :instance_type => 'c1.xlarge', :market => 'SPOT', :bid_price => '0.25', :name => 'Burst Capacity' }
# emr.add_instance_groups('jobflow_id', [instance_group_config])

# main
if __FILE__ == $0
  evolution = Time.now.to_i.to_s
  generation = 0
  population = Array.new(INITIAL_POPULATION) { Chromosome.new }
  ARGV.each { |file| population.unshift Chromosome.new(ParamsMatrix.new(File.open(file))) }

  AWS::S3::Base.establish_connection! :access_key_id => ENV['AWS_ACCESS_KEY_ID'], :secret_access_key => ENV['AWS_SECRET_KEY']
  emr = Elasticity::EMR.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_KEY"], :region => 'us-west-1')

  loop do
    player_seed = rand(1_000_000)
    engine_seed = rand(1_000_000)

    puts "Starting generation #{generation} with population #{population.size}"
    generation_path = "/evolutions/#{evolution}/generations/#{generation}"
    generation_input = "#{generation_path}/input"
    generation_output = "#{generation_path}/output"

    # for each chromosome and map, generate a work unit in s3
    puts "Uploading work units to S3"
    population.each do |chromosome|
      MAPS.each do |map|
        command = chromosome.fitness_command('master', player_seed, engine_seed, map)
        command_digest = Digest::SHA1.hexdigest(command)
        s3_path = "#{generation_input}/#{command_digest}.sh"
        AWS::S3::S3Object.store(s3_path, command, BUCKET)
      end
    end
    puts "Done uploading"


    puts "Checking for an existing job flow"
    waiting = emr.describe_jobflows.find { |jf| jf.state == 'WAITING' }
    jobflow_id = nil
    if waiting.nil?
      puts "No existing job flow, starting a new one"

      flow_config = {
        :name => "Evolution #{evolution}",
        :log_uri => 's3n://ant-chromosomes/logs/',
        :bootstrap_actions => [
                               :name => 'Git, Ruby, Python, Code',
                               :script_bootstrap_action => {
                                 :path => 's3n://ant-chromosomes/bootstrap/install_ruby_and_git.sh',
                               }
                              ],
        :instances => {
          :hadoop_version => '0.20',
          :keep_job_flow_alive_when_no_steps => true,
          :ec2_key_name => 'mapreduce-west',
          :instance_count => 2,
          :master_instance_type => 'm1.small',
          :slave_instance_type => 'c1.xlarge',
        },
        :steps => [],
      }

      jobflow_id = emr.run_job_flow(flow_config)
      puts "Started new job flow #{jobflow_id}"
    else
      jobflow_id = waiting.jobflow_id
      puts "Reusing job flow #{jobflow_id}"
    end

    puts "Adding a new step to #{jobflow_id}"
    step_config = {
      :name => "Generation #{generation}",
      :action_on_failure => 'CANCEL_AND_WAIT',
      :hadoop_jar_step => {
        :jar => '/home/hadoop/contrib/streaming/hadoop-streaming.jar',
        :args => [
                  '-input'  , "s3n://#{BUCKET}#{generation_input}/*",
                  '-output' , "s3n://#{BUCKET}#{generation_output}",
                  '-mapper' , '/bin/sh',
                  '-reducer', '/bin/cat',
                 ],
      },
    }

    emr.add_jobflow_steps(jobflow_id, :steps => [step_config])

    puts "Waiting for step to complete"
    loop do
      sleep 60
      jf = emr.describe_jobflows.find { |jf| jf.jobflow_id == jobflow_id }
      break if jf.state == 'WAITING'
      print '.'
    end
    puts "done!"

    puts "Fetching results from #{generation_output}"
    results = AWS::S3::S3Object.value("#{generation_output}/part-00000", BUCKET)
    scores = results.split("\n").map do |line|
      genome, _, _, _, _, _, playerscore, *otherscores = line.split(/\s+/)
      playertotal = playerscore.to_i
      othertotal = otherscores.map(&:to_i).inject(&:+)
      score = playertotal.to_f / (playertotal + othertotal)
      [genome, score]
    end

    groups = scores.group_by(&:first)
    groups.each do |data, tuples|
      chromosome = population.find { |c| c.data == data }
      average_score = tuples.map(&:last).inject(&:+) / tuples.size
      chromosome.fitness = average_score
    end

    # Join the results
    ranked = population.sort_by { |c| c.fitness }.reverse
    puts "Fitness scores: #{ranked.map(&:fitness).inspect}"

    # Save the winner
    ParamsMatrix.write(File.open("best-#{Process.pid}-#{generation}", "w"), ranked.first.matrix)

    generation += 1

    # Create new generation from elite, mutants, crossovers, and randoms
    new_population = [
                      ranked.first,
                      ranked.second,
                      ranked.first.mutation,
                      ranked.second.mutation,
                    ]
    ranked.first(10).each_slice(2) do |mom, dad|
      kids = mom.crossover(dad)
      new_population += kids
    end

    new_population += Array.new(6) { Chromosome.new }
    population = new_population
  end
end
