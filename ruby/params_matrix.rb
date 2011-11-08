require 'matrix'
require 'stringio'

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

  def self.to_base64(matrix)
    io = StringIO.new
    write(io, matrix)
    [io.string].pack("m0")
  end

  def self.from_base64(str)
    bytes = str.unpack("m0").first
    io = StringIO.new(bytes)
    read(io)
  end

  def self.with_binary_io(io)
    io.binmode
    return yield
  ensure
    io.close
  end
end
