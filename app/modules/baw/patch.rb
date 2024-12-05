# frozen_string_literal: true

module Baw
  # Our hook to load patches after rails has booted.
  module Patch
    def self.apply
      Rails.logger.debug('Baw:Patch.apply')

      ::Arel.extend(Baw::Arel)
      ::Arel::Expressions.prepend(Baw::Arel::ExpressionsExtensions)

      ::Arel::Nodes::Node.include(Baw::Arel::NodeExtensions)
      ::Arel::Nodes::SqlLiteral.include(Baw::Arel::NodeExtensions)

      ::Arel::Attributes::Attribute.include(Baw::Arel::AttributeExtensions)
      ::Arel::Visitors::ToSql.prepend(Baw::Arel::Visitors::ToSqlExtensions)

      AASM.prepend Baw::Aasm
    end
  end
end
