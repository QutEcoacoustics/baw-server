# frozen_string_literal: true

describe Hash do
  describe '#deep_map' do
    let(:example) { { a: { b: { c: 1 } }, d: [2, 3, 5, { e: 8, f: 9 }] } }

    it 'iterates over all elements' do
      values = []

      example.deep_map do |_context, value|
        values << value
      end

      expect(values).to eq([1, 2, 3, 5, 8, 9])
    end

    it 'preserves keys for all elements' do
      keys = []

      example.deep_map do |context, _value|
        keys << context
      end

      expect(keys).to  eq([[:a, :b, :c], [:d, 0], [:d, 1], [:d, 2], [:d, 3, :e], [:d, 3, :f]])
    end

    it 'is compatible with dig' do
      example.deep_map do |context, value|
        expect(example.dig(*context)).to eq(value)
      end
    end

    it 'can delete elements' do
      result = example.deep_map { |context, value|
        throw :delete if context.last == :e

        value
      }

      expect(result).to eq({ a: { b: { c: 1 } }, d: [2, 3, 5, { f: 9 }] })
    end

    it 'can delete elements from arrays and hashes' do
      result = example.deep_map { |_context, value|
        throw :delete if value.odd?

        value
      }

      expect(result).to eq({ d: [2, { e: 8 }] })
    end

    it 'can keep elements from based on key' do
      result = example.deep_map { |context, value|
        throw :delete if context.include?(:d)

        value
      }

      expect(result).to eq({ a: { b: { c: 1 } } })
    end

    it 'can transform values' do
      result = example.deep_map { |_context, value|
        value * 2
      }

      expect(result).to eq({ a: { b: { c: 2 } }, d: [4, 6, 10, { e: 16, f: 18 }] })
    end
  end
end
