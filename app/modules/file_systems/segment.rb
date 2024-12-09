# frozen_string_literal: true

module FileSystems
  # allows us to simply identify segments even if they are identical string
  # values. We can also tag special segment values
  Segment = Data.define(:name, :tag, :index, :last)

  # we can do this is the define block but our language server is not
  # smart enough to know that it is equivalent to the class_eval block.
  class Segment
    # Convert an array of path segments to an enumerator of `Segment`s.
    # Automatically adds the root, children, and grandchildren segments.
    # The last supplied segment is marked as the last segment.
    # Children and grandchildren occur after
    # @param segments [Array<String>] the path segments
    # @return [Enumerator<Segment>]
    def self.path_list_to_segments(segments)
      length = segments.length

      Enumerator.new(length + 3) do |y|
        y << Segment.new(nil, :root, 0, length.zero?)
        segments.each_with_index do |segment, index|
          last = index == length - 1

          y << Segment.new(segment, nil, index, last)
        end
        y << Segment.new(nil, :children, length + 1, false)
        y << Segment.new(nil, :grandchildren, length + 2, false)
      end
    end

    def root?
      tag == :root
    end

    def children?
      tag == :children
    end

    def grandchildren?
      tag == :grandchildren
    end

    # if this was the last user supplied segment
    # (:children and :grandchildren are not user supplied segments
    #  and still come after the last user supplied segment)
    # @return [Boolean]
    def last?
      last
    end

    # is this segment special?
    # i.e. one of :root, :children, or :grandchildren.
    def special?
      !tag.nil?
    end

    def not_special?
      tag.nil?
    end

    def to_s
      name&.to_s
    end

    def to_str
      name.nil? ? '' : name.to_s
    end
  end
end
