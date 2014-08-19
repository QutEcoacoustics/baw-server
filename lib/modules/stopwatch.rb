
# from https://gist.github.com/schacon/1040423
class Stopwatch

  attr_writer :splits, :max, :start, :end, :total

  def initialize(message)
    @message = message
    @splits = []
    @max = 5
  end

  def split(message)
    @max = message.size > @max ? message.size : @max
    time = Time.now
    @start = time unless @start
    @end = time
    @splits << [time, message]
  end

  def report
    puts
    @total = @end - @start
    last_time = nil
    last_message = nil
    @splits.each do |split|
      time, message = split
      if last_time
        elapsed = time - last_time
        ptime(last_message, elapsed)
      end

      last_time = time
      last_message = message
    end
    ptime("Total", @total)
  end

  def ptime(message, time)
    extra = ''
    if time < @total
      extra = ((time / @total) * 100).to_i.to_s + '%'
    end
    puts message.rjust(@max + 1) + ' ' + time.to_s.rjust(10) + ' ' + extra
  end
end