# frozen_string_literal: true

module Api
  class AudioEventParser
    # Combines a list of transformers, returning the first successful result
    class EitherTransformer
      include Dry::Monads[:maybe]

      def initialize(*transformers)
        @transformers = transformers

        raise ArgumentError, 'At least one transformer is required' if @transformers.empty?
        raise ArgumentError, 'All transformers must be KeyTransformers' unless @transformers.all? { |t|
          t.is_a? KeyTransformer
        }
        raise ArgumentError, 'All transformers must agree on the multi option' unless are_all_same?
      end

      def extract_key(hash)
        @transformers.each do |transformer|
          result = transformer.extract_key(hash)
          return result if result.success?
        end

        None()
      end

      private

      def are_all_same?
        first = @transformers.first.multi

        @transformers.all? { |t| t.multi == first }
      end
    end
  end
end
