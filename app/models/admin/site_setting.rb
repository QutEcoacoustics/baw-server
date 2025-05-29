# frozen_string_literal: true

# == Schema Information
#
# Table name: site_settings
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  value      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_site_settings_on_name  (name) UNIQUE
#
module Admin
  # Database settings for the application. Dynamic.
  # See also `config/initializers/04_site_settings.rb` for the `SiteSettings` alias.
  class SiteSetting < ApplicationRecord
    include DynamicSettings

    # @!parse
    #   class << self
    #     # The maximum number of items allowed to be enqueued at once for batch analysis.
    #     # @return [Integer]
    #     attr_accessor :batch_analysis_remote_enqueue_limit
    #   end
    define_setting(
      :batch_analysis_remote_enqueue_limit,
      ::BawApp::Types::Params::Integer.optional.constrained(gteq: 0),
      'The maximum number of items allowed to be enqueued at once for batch analysis.',
      Settings.batch_analysis.remote_enqueue_limit
    )

    def self.filter_settings
      {
        valid_fields: [:name, :value],
        render_fields: [:id, :name, :value, :description, :type_specification, :created_at, :updated_at],
        text_fields: [:name, :description],
        custom_fields2: {},
        controller: :site_settings,
        defaults: {
          order_by: :name,
          direction: :asc
        },
        action: :index,
        capabilities: {},
        valid_associations: []

      }
    end

    def self.schema
      {
        type: :object,
        properties: {
          id: Api::Schema.id(nullable: true),
          name: { type: :string, enum: known_settings.keys },
          # any type
          value: { nullable: true },
          description: { type: :string },
          type_specification: { type: :string },
          created_at: Api::Schema.date(nullable: true),
          updated_at: Api::Schema.date(nullable: true),
          required: ['name', 'value'],
          additionalProperties: false
        }
      }
    end
  end
end
