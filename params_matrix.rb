require 'matrix'

class ParamsMatrix
  ROWS = 8
  COLS = 8

  def initialize(io)
    io.binmode
    packed = io.read
    data = packed.unpack("C*")
    @matrix = Matrix.build(ROWS, COLS) { data.shift }
    io.close
  end

  def write(io)
    io.binmode
    data = []
    @matrix.each { |elt| data << elt }
    packed = data.pack("C*")
    io.write(packed)
    io.close
  end

  def to_priorities(stats_vector)
    @matrix * stats_vector
  end
end
