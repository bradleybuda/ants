class ParamsMatrix
  def initialize(io)
    io.binmode
    packed = io.read
    @matrix = packed.unpack("C*")
    io.close
  end

  def write(io)
    io.binmode
    packed = @matrix.pack("C*")
    io.write(packed)
    io.close
  end

  def to_priorities(stats)
    weights_size = @matrix.size / stats.size
    vectors = @matrix.each_slice(stats.size)

    Array.new(weights_size) do |i|
      stats.zip(vectors.next).inject(0) { |sum, (x, y)| sum + x*y }
    end
  end
end
