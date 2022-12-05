# frozen_string_literal: true

module BawApp
  # https://gist.github.com/ubermajestix/3644301
  module Inspector
    def inspect
      string = "#<#{self.class.name}:#{object_id} "
      fields = self.class.inspector_fields.map { |field| "#{field}: #{send(field)}" }
      string << fields.join(', ') << '>'
    end

    def self.inspected
      @inspected ||= []
    end

    def self.included(source)
      # $stdout.puts "Overriding inspect on #{source}"
      inspected << source
      source.class_eval do
        def self.inspector(*fields)
          @inspector_fields = *fields
        end

        def self.inspector_fields
          @inspector_fields ||= []
        end
      end
    end
  end
end
