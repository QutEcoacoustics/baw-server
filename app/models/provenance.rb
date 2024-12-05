# frozen_string_literal: true

require 'validate_url'

# == Schema Information
#
# Table name: provenances
#
#  id                                                                     :integer          not null, primary key
#  deleted_at                                                             :datetime
#  description(Markdown description of this source)                       :text
#  name                                                                   :string
#  score_maximum(Upper bound for scores emitted by this source, if known) :decimal(, )
#  score_minimum(Lower bound for scores emitted by this source, if known) :decimal(, )
#  url                                                                    :string
#  version                                                                :string
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  creator_id                                                             :integer
#  deleter_id                                                             :integer
#  updater_id                                                             :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
class Provenance < ApplicationRecord
  extend Enumerize

  # relationships
  belongs_to :creator, class_name: 'User', inverse_of: :created_provenances
  belongs_to :updater, class_name: 'User', inverse_of: :updated_provenances, optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_provenances, optional: true

  has_many :audio_events, inverse_of: :provenance
  has_many :scripts, inverse_of: :provenance

  # add deleted_at and deleter_id
  acts_as_discardable

  # attribute validations
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :version }
  validates :url, url: { allow_nil: true }

  renders_markdown_for :description

  # Define filter api settings
  def self.filter_settings
    fields = [
      :id, :name, :version, :url, :description, :score_minimum, :score_maximum,
      :creator_id, :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at
    ]
    {
      valid_fields: fields,
      render_fields: fields + [:description_html_tagline, :description_html],
      text_fields: [:name, :description],
      #custom_fields: nil,
      custom_fields2: {
        **Provenance.new_render_markdown_for_api_for(:description)
      },
      new_spec_fields: lambda { |_user|
                         {
                           name: nil,
                           description: nil,
                           score_minimum: nil,
                           score_maximum: nil,
                           version: nil,
                           url: nil
                         }
                       },
      controller: :provenances,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      },
      #capabilities: {},
      valid_associations: []
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.all_user_stamps,
        version: { type: 'string' },
        url: { type: 'string', format: 'uri' },
        score_minimum: { type: ['number', 'null'] },
        score_maximum: { type: ['number', 'null'] }
      },
      required: [
        :id,
        :name,
        :description,
        :description_html,
        :description_html_tagline,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at,
        :version,
        :url,
        :score_minimum,
        :score_maximum
      ]
    }.freeze
  end
end
