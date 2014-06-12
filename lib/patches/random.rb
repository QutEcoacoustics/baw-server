# https://gist.github.com/phluid61/5107356
class << Random
  def rand_incl(max=1.0)
    raise ArgumentError 'maximum not greater than 0' if max <= 0.0
    if @incl_lim.nil?
      @incl_lim = (1 / Float::EPSILON).to_i
      @incl_lim1 = @incl_lim + 1
    end
    if Float === max
      max*rand(@incl_lim1) / @incl_lim
    else
      rand(max+1)
    end
  end
end