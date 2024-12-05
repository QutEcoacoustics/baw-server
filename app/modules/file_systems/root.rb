# frozen_string_literal: true

module FileSystems
  # The root of the virtual file system
  class Root < Layer
    attr_reader :base_path, :base_query

    def initialize(base_path, base_query)
      super()
      @base_path = base_path
      @base_query = base_query

      raise ArgumentError, 'base_path must be a string' unless base_path.is_a?(String)

      unless base_path.start_with?(FileSystems::RouteSet::DIRECTORY_DELIMITER)
        raise ArgumentError, 'base_path must start with a slash'
      end

      return if base_query.is_a?(ActiveRecord::Relation)

      raise ArgumentError,
        'base_query must be an ActiveRecord::Relation'
    end

    def consume_segments(sub_segments, _data)
      # this is the root layer, it consumes the special :root token
      raise unless sub_segments.first.root?

      # if this is really the root layer then RouteSet will stop scanning
      # because there are no more segments to scan
      # otherwise, RouteSet will continue scanning and this layer won't be selected
      1
    end

    def show(_data)
      FileSystems::Structs::DirectoryWrapper.new(
        path: @base_path,
        name: ''
      )
    end

    def list(_data)
      # listing only happens when the target layer is the parent of this one
      # and nothing can be the parent of the root layer
      raise Error, 'Root layer does not support listing'
    end

    def have_children(_children, _data)
      # have_children only happens when the target layer is the grandparent
      # of this one and nothing can be the parent of the root layer
      raise Error, 'Root layer does not support listing grandchildren'
    end

    def make_path(*segments)
      base_path + RouteSet::DIRECTORY_DELIMITER + segments.flatten.join(RouteSet::DIRECTORY_DELIMITER)
    end

    def additional_data(items)
      return {} if items.blank?

      key = :"#{base_query.model.model_name.element}_ids"
      ids = items.map { |item1| item1.is_a?(ActiveRecord::Base) ? item1&.id : item1 }
      {
        key => ids
      }
    end
  end
end
