# frozen_string_literal: true

# Allows for a model to define dynamic settings that are stored in the database.
# Each setting is stored in its own row in the site_settings table.
# The settings can be accessed via class methods which will load or write the
# setting from the database.
#
# The settings are defined using the `define_setting` class method.
#
# The settings are cached in memory for performance reasons.
# The cache is cleared when the model is reloaded or when the settings are reset.
#
# @example
#   class MyModel < ApplicationRecord
#     include DynamicSettings
#
#     define_setting :my_setting, :BawApp::Types::Params::Integer.constrained(gteq: 0), 'My setting description', 1234
#   end
#
#   MyModel.my_setting # => 1234 # The default value
#   MyModel.my_setting = '5678'
#   MyModel.my_setting # => 5678
module DynamicSettings
  extend ActiveSupport::Concern

  class UnknownSettingError < StandardError; end
  class InvalidSettingError < StandardError; end

  # Ensures active record attribute values are deserialized as symbols
  class SymbolValue < ::ActiveRecord::Type::Value
    include Singleton

    def cast_value(value)
      return if value.nil?

      value.to_sym
    end

    def serialize(value)
      return if value.nil?

      value.to_s
    end
  end

  included do
    attribute(:name, SymbolValue.instance)

    validates :name, presence: true, uniqueness: true
    validates :value, presence: true
    validate :value_is_correct_type
    validate :name_is_a_known_setting

    after_find do
      # Update the cache with the loaded setting
      self.class.settings_cache[name] = self

      # Take the opportunity to convert the value to the correct type
      # This is done here because the ActiveRecord::Type::Value class
      # cannot use other fields to deserialize the value and we need
      # the name to fetch the type specification.
      _write_attribute('value', try_convert_value(read_attribute(:value)))
    end

    after_destroy do
      self.class.settings_cache.delete(name)
    end
  end

  class_methods do
    def settings_cache
      @settings_cache ||= {}
    end

    def known_settings
      @known_settings ||= {}
    end

    # Define a setting with the given name, type, description, and default value.
    # Unlike normal attributes each setting is stored in it's own row in the
    # site_settings table.
    # Each of the settings are meant to be accessed via class methods which will
    # in turn take care of loading or writing the setting from the database.
    #
    # @param name [Symbol] The name of the setting.
    # @param type_specification [::Dry::Types::Type] The type specification for the setting.
    # @param description [String] The description of the setting.
    # @param default [Object] The default value for the setting.
    # @return [void]
    def define_setting(name, type_specification, description, default = nil)
      raise ArgumentError, 'Setting name must be a symbol' unless name.is_a?(Symbol)

      unless type_specification.is_a?(Dry::Types::Type)
        raise ArgumentError,
          'type_specification must be a Dry::Types::Type'
      end

      raise ArgumentError, 'description must be a string' unless description.is_a?(String)

      raise ArgumentError, 'Cannot define a known setting twice' if known_settings.include?(name)

      known_settings[name] = { type_specification:, description:, default: }

      # Define the getter method for the setting
      define_singleton_method(name) do
        # Load the setting from the database if it doesn't exist in memory
        get_setting(name)
      end

      # Define the setter method for the setting
      define_singleton_method("#{name}=") do |value|
        save_setting(name, value)
      end
    end

    # Load the setting from the database or return the default value if not found.
    # @param name [Symbol] The name of the setting.
    # @param type_specification [Dry::Types::Type] The type specification for the setting.
    # @param default [Object] The default value for the setting.
    # @return [DynamicSettings] The DynamicSetting model.
    def load_setting(name)
      name = name&.to_sym unless name.is_a?(Symbol)
      # Check if the setting is already loaded in memory
      return settings_cache[name] if settings_cache&.key?(name)

      raise UnknownSettingError, "Setting #{name} is not defined" unless known_settings.key?(name)

      # Load the setting from the database
      # setting is added to the cache in the after_find callback, if it is found
      setting = find_by(name:)

      # If the setting is not found, return the default value
      setting = build_default_setting(name) if setting.nil?

      setting
    end

    def load_all_settings
      persisted = all
      not_persisted = known_settings.keys - persisted.map(&:name)
      defaults = not_persisted.map { |name| build_default_setting(name) }

      persisted + defaults
    end

    # Get the setting value from the database or return the default value if not found.
    # @param name [Symbol] The name of the setting.
    # @return [Object] The value of the setting.
    def get_setting(name)
      setting = load_setting(name)

      setting.value
    end

    # Save the setting to the database and update the cache.
    # Does an upsert in the database.
    # @param name [Symbol] The name of the setting.
    # @param value [Object] The value to save. It will be converted to a string.
    # @param description [String] The description of the setting.
    # @return [Object]
    def save_setting(name, value)
      # get an instance of the setting
      setting = load_setting(name)

      if value.nil?
        # If the value is nil, remove the setting from the database
        setting.destroy if setting.persisted?

        # Removing the setting from the cache done by the after_destroy callback
        return load_setting(name)
      end

      was_new_record = setting.new_record?

      setting.value = value

      # Validate the setting
      raise InvalidSettingError, "Invalid setting: #{setting.errors.full_messages.join(', ')}" unless setting.valid?

      # Upsert the setting in the database
      #rubocop:disable Rails/SkipsModelValidations -- valid is already called
      result = upsert(
        {
          name: setting.name,
          value: setting.value
        },
        unique_by: :name,
        returning: attribute_names,
        record_timestamps: true
      )

      # Update the cache with the new value
      result.first.each do |key, value_from_database|
        setting._write_attribute(key, type_for_attribute(key).deserialize(value_from_database))
      end

      if was_new_record
        setting.instance_variable_set(:@new_record, true)
        setting.instance_variable_set(:@previously_new_record, true)
      end

      # we've updated they cached object's attributes already, so now just return it
      setting
    end

    # Empties the in-memory cache of settings.
    def clear_cache
      settings_cache.clear
    end

    # Delete all settings from the database and clear the cache.
    def reset_all_settings!
      clear_cache

      delete_all
    end

    def build_default_setting(name)
      known_settings[name] => { default: }

      # If the setting is not found, return the default value
      build(name:, value: default)
    end
  end

  def value
    try_convert_value(super)
  end

  # An instance method so we can serialize the setting description
  # in the API response.
  def description
    self.class.known_settings[name]&.fetch(:description)
  end

  # An instance method so we can serialize the setting description
  # in the API response.
  def type_specification
    self.class.known_settings[name]&.fetch(:type_specification)
  end

  # An instance method so we can serialize the setting description
  # in the API response.
  def default
    self.class.known_settings[name]&.fetch(:default)
  end

  def as_json
    super.merge(
      'description' => description,
      'type_specification' => type_specification.name,
      'default' => default
    )
  end

  private

  # Try to convert the value to the specified type
  def try_convert_value(value)
    type = type_specification

    # don't raise an error if type specification is missing, we want our validation to handle it
    return value if type.nil?

    return type[value] if type.valid?(value)

    # If the value is not valid, return the original value
    value
  end

  def name_is_a_known_setting
    return if self.class.known_settings.include?(name)

    errors.add(:name, 'is not a known setting')
  end

  def value_is_correct_type
    type = type_specification

    # don't raise an error if type specification is missing, we want our validation to handle it
    return if type.nil?

    return if type.valid?(value)

    errors.add(:value, "must be of type #{type.name}")
  end
end
