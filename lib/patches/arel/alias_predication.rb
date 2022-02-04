# frozen_string_literal: true

require 'arel_extensions'

module Baw
  module ArelExtensions
    module Visitors
      module Arel
        module Visitors
          module PostgreSQL
            # https://github.com/rails/rails/pull/43911/files introduced a breaking change where aliases are more likely to
            # be quoted. Something, likely arel_extensions.
            # https://github.com/rails/rails/issues/44099 seems to indicate arel_extensions is the root cause

            def visit_Arel_Nodes_As(o, collector)
              if o.left.is_a?(::Arel::Nodes::Binary)
                collector << '('
                collector = visit o.left, collector
                collector << ')'
              else
                collector = visit o.left, collector
              end
              collector << ' AS '

              # sometimes these values are already quoted, if they are, don't double quote it
              quote = o.right.is_a?(::Arel::Nodes::SqlLiteral) && o.right[0] != '"' && o.right[-1] != '"'

              collector << '"' if quote
              collector = visit o.right, collector
              collector << '"' if quote

              collector
            end
          end
        end
      end
    end
  end
end

# When this PR is resolved we can remove this patch
# https://github.com/Faveod/arel-extensions/pull/54
ArelExtensions::Visitors.class_eval do
  Arel::Visitors::PostgreSQL.prepend ::Baw::ArelExtensions::Visitors::Arel::Visitors::PostgreSQL
end
warn 'Warn: patch removed arel_extensions patch of the `as` function'
