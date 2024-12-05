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

  # The opposite of dig. Sets a value at an arbitrary key depth.
  # If the intermediate keys or hashes do not exist they will be created.
  # For performance reasons this method is mutative.
  # @param keys [Array] - the key path to use
  # @param value [Object] - the value to set
  # @param default [Proc] - a proc to use to create new hashes
  # @param on_conflict [Proc] - a proc to use to resolve conflicts. The proc
  # receives the current value and the new value and should return the desired value.
  # Defaults to the new value.
  # @return [Hash] the modified hash
  def bury!(*keys, value:, default: -> { {} }, on_conflict: ->(_current, new) { new })
    raise 'key path required' if keys.empty?

    keys.flatten => [*rest, last]

    rest.reduce(self) do |current, key|
      current[key] = default.call unless current.key?(key)

      current[key]
    end => current

    if current.key?(last)
      on_conflict.call(current[last], value)
    else
      value
    end => value

    current[last] = value

    self
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
