# frozen_string_literal: true

class Hash
  raise 'deep_enumerate is already defined' if defined?(deep_enumerate)

  # Iterates deeply over a structure preserving context as keys.
  # If the block throws :delete the current key will be removed from the structure.
  # Empty hashes and arrays are removed.
  # @param value [Object] the item to iterate over
  # @yield [context, value] - the current keys as an array of context and the current value
  # @yieldparam context [Array] - the current keys as an array of context
  # @yieldparam value [Object] - the current value
  # @return [Object] the result of the block
  def deep_map(&block)
    raise 'block required' if block.nil?

    return self if empty?

    deep_map_internal(self, [], &block)
  end

  private

  # Iterates deeply over a structure preserving context as keys.
  # If the block throws :delete the current key will be removed from the structure.
  # Empty hashes and arrays are removed.
  # @param value [Object] the item to iterate over
  # @param context [Array] - an array of keys
  # @yield [context, value] - the current keys as an array of context and the current value
  # @yieldparam context [Array] - the current keys as an array of context
  # @yieldparam value [Object] - the current value
  # @return [Object] the result of the block
  def deep_map_internal(value, context, &block)
    case value
    when ::Hash
      result = value.class.new
      value.each do |key, item|
        catch(:delete) do
          result[key] = deep_map_internal(item, context + [key], &block)
        end
      end
      throw :delete if result.empty?
      result
    when ::Array
      result = value.class.new
      value.each_with_index do |item, index|
        catch(:delete) do
          result << deep_map_internal(item, context + [index], &block)
        end
      end
      throw :delete if result.empty?
      result
    else
      block.call(context, value)
    end
  end
end
