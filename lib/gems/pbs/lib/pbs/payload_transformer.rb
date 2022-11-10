# frozen_string_literal: true

module PBS
  # converts pbs qstat json into a format that we like
  class PayloadTransformer < ::Dry::Transformer::Pipe
    import ::Dry::Transformer::HashTransformations
    import ::Dry::Transformer::Conditional
    import ::Dry::Transformer::Recursion

    Inflector = Dry::Inflector.new

    import :underscore, from: Inflector, as: :underscore

    define! do
      recursion do
        is ::Hash do
          stringify_keys
          map_keys(&:underscore)
          symbolize_keys
        end
      end
    end
  end
end
