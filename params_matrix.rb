require 'matrix'

class ParamsMatrix
  ROWS = 8
  COLS = 8

  def self.read(io)
    with_binary_io(io) do
      packed = io.read
      data = packed.unpack("C*")
      Matrix.build(ROWS, COLS) { data.shift }
    end
  end

  def self.write(io, matrix)
    with_binary_io(io) do
      data = []
      matrix.each { |elt| data << elt }
      packed = data.pack("C*")
      io.write(packed)
    end
  end

  def self.with_binary_io(io)
    io.binmode
    return yield
  ensure
    io.close
  end
end
