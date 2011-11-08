class TimeoutLoop
  FUDGE = 0.9
  @@halted = false

  # Yield repeatedly until +duration+ seconds have elapsed. Goal is to
  # terminate the looping before time is up; i.e. when we predict that
  # the next iteration will take us over the budget
  def self.run(duration)
    @@halted = false
    start = Time.now.to_f
    # TODO measure iterations and predict the next iteration time
    cutoff = start + (duration * FUDGE)
    yield while !@@halted && (Time.now.to_f < cutoff)
    # TODO enable plug goal if timeout reached?
  end

  def self.halt!
    @@halted = true
  end
end
