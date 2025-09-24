# frozen_string_literal: true

module Report
  module Cte
    class NodeTemplate < Node
      # include TemplateAttributes
      class_attribute :default_name, default: nil
      class_attribute :default_suffix, default: nil
      class_attribute :default_select, default: nil
      class_attribute :default_dependencies, default: {}
      class_attribute :default_options, default: {}

      class << self
        def table_name(name)
          self.default_name = name.to_sym
        end

        def select(&blk)
          self.default_select = blk
        end

        def dependencies(**deps, &blk)
          self.default_dependencies = blk ? blk.call : deps
        end

        def options(**opts, &blk)
          self.default_options = blk ? blk.call : opts
        end
      end

      def initialize(suffix: nil, options: {})
        new_suffix = resolve_suffix(suffix)
        new_options = default_options.merge(options.symbolize_keys)
        validate_options new_options

        super(
          default_name,
          dependencies: default_dependencies,
          select: default_select,
          suffix: new_suffix,
          options: new_options
        )
      end

      # in most cases there won't be a default suffix. only when the same CTE table is needed more than once in the same
      # query. in the audio event report, 80% of the time this method is just returning nil. the coverage node is needed
      # twice. when the coverage_analysis node with a default suffix is built, this method is what returns the default
      # suffix. then when its dependencies are built, the suffix cascades down, and here `suffix` will be true and they
      # inherit the suffix.
      def resolve_suffix(suffix)
        suffix || default_suffix
      end

      def validate_options(new_options)
        # noop
      end

      # subclass factory
      def self.define_table(name, &block)
        klass = Class.new(self)

        klass.default_name = name
        klass.instance_eval(&block) if block
        klass
      end
    end
  end
end
