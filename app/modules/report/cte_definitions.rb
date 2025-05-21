# frozen_string_literal: true

def report_declarations_as_hash
  # This method is a placeholder for the actual implementation.
  # It should return a hash of report declarations.
  {}

end

# report field declarations
# register a custom output field
field_identifier_as_key = {
  type: :cte,
  projection: -> () { build_cte_two },
  gives: {
    table: -> () { Arel::Table.new('audio_events') },
    fields: []
  },
  gives_fields: [:audio_end_times, :audio_groupings],
  render_name: 'audio_recording_coverage',
  depends_on: [:cte_one]
}

# process the array of fields
# start a new collection to store the custom fields
# build the final query
# add the 'with' statement - collect from all registered ctes - .get.ctes

def build_cte_two
p 'building cte two'
p 'done'
end

class ReportField
  attr_accessor :name, :type, :options

  def initialize(name, type, options = {})
    @name = name
    @type = type
    @options = options
  end

  def to_hash
    {
      name: @name,
      type: @type,
      options: @options
    }
  end
end

def cte_declarations_as_hash
# register an output field

end