# frozen_string_literal: true

module BawApp
  # Customize inspect output in an easy fashion.
  # https://gist.github.com/ubermajestix/3644301
  module Inspector
    # Formats custom inspector outputs
    module Formatter
      INSPECTOR_IDENTITY = '🕵️'

      extend self

      def format_inspect(instance, options)
        vars = format_instance_variables(instance, options)

        # matches normal inspect output
        name = instance.class.name || instance.class.inspect

        "#<#{name}:#{instance.object_address}#{vars}>"
      end

      private

      def format_instance_variables(instance, options)
        options => { expository: }

        instance
          .instance_variables
          .map { |field|
            if show?(field, **options)
              "#{field}=#{instance.instance_variable_get(field).inspect}"
            elsif expository
              "#{field}=(#{INSPECTOR_IDENTITY} HIDDEN)"
            end

            # implicit nil return here if expository is false and show is false
          }
          .compact
          .join(', ') => vars

        vars.blank? ? '' : " #{vars}"
      end

      def show?(field, includes:, excludes:, predicate:, **_other)
        show = true
        show &&= predicate.call(field) if predicate
        show &&= includes.include?(field) if includes.any?
        show &&= excludes.exclude?(field) if excludes.any?

        show
      end
    end

    # Macro for changing the inspect method
    module ClassMethods
      # Customize the inspect method by including or excluding instance variables.
      # Filters are evaluated in this order: block -> includes -> excludes with the first exclusion winning
      # @param includes [Array<Symbol>]
      # @param excludes [Array<Symbol>]
      # @param expository  [Boolean] if true then the inspector will explain when a instance variable is missing.
      # @yield [Symbol] predicate to filter instance variables, return true to include, false to exclude
      # @yieldparam [Symbol] field
      # @yieldreturn [Boolean]
      # @return [void]
      def inspector(includes: [], excludes: [], expository: false, &predicate)
        includes = includes.map { |field| field.start_with?('@') ? field : :"@#{field}" }
        excludes = excludes.map { |field| field.start_with?('@') ? field : :"@#{field}" }

        inspector_options = { includes:, excludes:, expository:, predicate: }

        custom_inspect = Module.new do
          define_method(:inspect) do
            Formatter.format_inspect(self, inspector_options)
          end
        end

        include custom_inspect
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
