# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    # Represents a resource that can scale with the size of the input recording
    class Polynomial < ::Dry::Struct
      transform_keys(&:to_sym)

      # @!attribute [r] coefficients
      #   The coefficients of the polynomial in descending order of exponent.
      #   e.g. `[a^3, a^2, a^1, a^0]`
      #   @return [Array<Number>]
      attribute :coefficients, ::BawApp::Types::Array.of(
        ::BawApp::Types::JSON::Decimal
      )

      # @!attribute [r] property
      #   @return [Symbol]
      attribute :property, ::BawApp::Types::Coercible::Symbol

      def calculate(recording_duration:, recording_size:)
        case property
        in :size
          recording_size
        in :duration
          recording_duration
        else
          raise "Unknown property '#{property}' for calculating resources."
        end => input

        coefficients
          .each_with_index.reduce(0) { |sum, pair|
            coefficient, index = pair
            exponent = coefficients.length - index - 1
            sum + (coefficient * (input**exponent))
          }
          .round
      end

      # Combines two polynomials.
      def combine(other)
        raise 'Cannot combine polynomials with different properties.' if property != other.property

        combined = coefficients
          .zip_from_end(other.coefficients)
          .map { |(a, b)|
            a.to_d + b.to_d
          }
          .to_a

        Polynomial.new(coefficients: combined, property:)
      end
    end

    ConstantOrPolynomial = (Polynomial | ::BawWorkers::Dry::Types::JSON::Decimal).constructor { |value|
      case value
      in Polynomial
        value
      in Hash
        Polynomial.new(**value)
      in ::Numeric
        value.to_d
      else
        raise "Cannot coerce #{value} to a constant or polynomial."
      end
    }

    # Resources to request for a job that can scale with the size of the input recording
    class DynamicResourceList < ::Dry::Struct
      transform_keys(&:to_sym)

      # @!attribute [r] ncpus the number of CPUs to request
      #   @return [Number, Polynomial, nil]
      attribute :ncpus, ConstantOrPolynomial.optional.default(nil)

      # @!attribute [r] walltime the maximum walltime to request in seconds
      #   @return [Number, Polynomial, nil]
      attribute :walltime, ConstantOrPolynomial.optional.default(nil)

      # @!attribute [r] mem the amount of memory to request in bytes
      #   @return [Number, Polynomial, nil]
      attribute :mem, ConstantOrPolynomial.optional.default(nil)

      # @!attribute [r] ngpus the number of GPUs to request
      #   @return [Number, Polynomial, nil]
      attribute :ngpus, ConstantOrPolynomial.optional.default(nil)

      # Resolves resources from polynomials to constant values.
      # @param [Integer] recording_duration the duration of the recording in seconds
      # @param [Integer] recording_size the size of the recording in bytes
      # @param [Hash<Symbol,Integer>] minimums the minimum values to use for each resource
      # @return [Hash<Symbol,Integer>]
      def calculate(recording_duration:, recording_size:, minimums: {})
        attributes.filter_map { |key, value|
          case value
          in Polynomial
            value.calculate(recording_duration:, recording_size:).to_i
          else
            value&.to_i
          end => calculated_value

          minimum = minimums.fetch(key, nil)

          if minimum.present?
            calculated_value = minimum if calculated_value.nil?
            calculated_value = minimum if minimum > calculated_value
          end

          next if calculated_value.nil?

          [key, calculated_value]
        }.to_h
      end

      # Combines two resource lists.
      # Constant values are simply added together.
      # Polynomial values are combined by adding their coefficients.
      # Will error if scaling properties are different.
      # @param [DynamicResourceList] other the other resource list to combine with
      # @return [DynamicResourceList]
      def combine(other)
        resources = attributes.to_h { |key, value|
          other_value = other.send(key)
          new_value = combine_two(value, other_value)

          [key, new_value]
        }
        new(**resources)
      end

      private

      def combine_two(value, other_value)
        return nil if value.nil? && other_value.nil?

        value = 0 if value.nil?
        other_value = 0 if other_value.nil?

        case [value, other_value]
        in [Polynomial, Polynomial]
          value.combine(other_value)
        in [Polynomial, ::Numeric]
          coefficients = combine_coefficients_and_number(value.coefficients, other_value)
          value.new(coefficients:)
        in [::Numeric, Polynomial]
          coefficients = combine_coefficients_and_number(other_value.coefficients, value)
          other_value.new(coefficients:)
        in [::Numeric, ::Numeric]
          value + other_value
        else
          raise "Cannot combine values for #{value} and #{other_value}."
        end
      end

      def combine_coefficients_and_number(coefficients, number)
        if coefficients.empty?
          [number.to_d]
        else
          coefficients[-1] = coefficients[-1].to_d + number.to_d
          coefficients
        end
      end
    end
  end
end
