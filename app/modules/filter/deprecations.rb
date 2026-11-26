# frozen_string_literal: true

module Filter
  # Collects the deprecated features used by a filter request.
  # They are reported to the client in the response's `meta.warning` and logged.
  class Deprecations
    include SemanticLogger::Loggable

    # How each part of a request is described in a warning.
    USAGES = {
      filter: 'Filtering on',
      projection: 'Projecting',
      sorting: 'Sorting by'
    }.freeze

    def initialize
      @one_to_many_associations = USAGES.keys.index_with { Set.new }
    end

    # Record the use of a dotted field that reaches through a one-to-many association.
    # Conditions on these fields don't apply to the same associated row, and projecting or sorting by them duplicates
    # rows. See https://github.com/QutEcoacoustics/baw-server/issues/1076.
    # @param usage [Symbol] where the field was used, one of USAGES
    # @param field [Symbol] the dotted field name
    # @return [void]
    def add_warning_for_one_to_many_association(usage, field)
      raise ArgumentError, "Unknown usage `#{usage}`" unless USAGES.key?(usage)
      return unless @one_to_many_associations[usage].add?(field)

      logger.warn(one_to_many_association_warning({ usage => [field] }))
    end

    # @return [String, nil] a warning for every recorded deprecation, or nil if there are none
    def compile_warning
      used = @one_to_many_associations.reject { |_usage, fields| fields.empty? }
      return if used.empty?

      one_to_many_association_warning(used)
    end

    private

    def one_to_many_association_warning(fields_by_usage)
      sentences = fields_by_usage.map { |usage, fields|
        "#{USAGES[usage]} one-to-many relationships is unpredictable and deprecated: " \
          "#{fields.map { |field| "`#{field}`" }.join(', ')}."
      }

      sentences.join(' ')
    end
  end
end
