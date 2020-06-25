# frozen_string_literal: true

# An Arel Attribute does not expose information (publicly) about the column
# type it is working with. Let's crack that nut open!
# https://github.com/rails/rails/blob/a6e98b2267a4470c2de4aa3eb16651c161d98091/activerecord/lib/arel/attributes/attribute.rb#L12-L14
module Baw
  module Arel
    module Attributes
      module AttributeHelpers
        # this exists in the tip of rails, but not yet in any release
        def type_caster
          # make sure we're aware if a framework version of this method ever
          # becomes defined!
          raise 'type_caster patch no longer required' if defined?(super)

          caster = relation.send(:type_caster)
          caster.send(:types).type_for_attribute(name).type
        end
      end
    end
  end
end

Arel::Attributes::Attribute.prepend Baw::Arel::Attributes::AttributeHelpers
