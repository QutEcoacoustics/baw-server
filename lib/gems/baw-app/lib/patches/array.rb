# frozen_string_literal: true

class Array
  # Combines two arrays, matching elements from the end.
  # If one array is longer than the other, the shorter array is padded with nil.
  # @param [Array] other the other array to combine with
  # @return [Enumerator<Array>] an array of arrays, each containing one element from each array
  def zip_from_end(other)
    return [] if other.nil?

    a_length = length
    b_length = other.length
    total_length = [a_length, b_length].max

    a_offset = total_length - a_length
    b_offset = total_length - b_length

    Enumerator.new(total_length) do |y|
      total_length.times do |i|
        a_index = i - a_offset
        b_index = i - b_offset
        a = a_index.negative? ? nil : self[a_index]
        b = b_index.negative? ? nil : other[b_index]

        y << [a, b]
      end
    end
  end

  # Unwraps an array with a single element.
  # @return [Object,Array<Object>] the single element if the array has a length of 1, otherwise the array itself
  def unwrap
    if length == 1
      first
    else
      self
    end
  end

  # Deinterlaces an array into two arrays.
  # @yield [Object,Object] the two elements to be processed. If the block returns
  #   false, the elements are not included in the result.
  # @return [Array<Array>] two arrays, one containing the even-indexed elements
  #   and the other containing the odd-indexed elements
  def deinterlace
    as = []
    bs = []

    each_slice(2) do |a, b|
      if block_given?
        result = yield a, b

        next unless result
      end

      as << a
      bs << b
    end

    [as, bs]
  end
end
