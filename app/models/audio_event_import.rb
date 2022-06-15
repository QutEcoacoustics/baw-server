# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_imports
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  files       :jsonb
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  deleter_id  :integer
#  updater_id  :integer
#
class AudioEventImport < ApplicationRecord
  # Temporary property showing events recently imported.
  # @return [Array<AudioEvent>]
  attr_accessor :imported_events

  # relations
  has_many :audio_events, inverse_of: :audio_event_import

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_events
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_events,
    optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_events,
    optional: true

  after_initialize :set_defaults

  # scopes
  # @!method self.created_by(user)
  #   Finds records created by given user
  #   @param user [User] User to filter by
  #   @return [::ActiveRecord::Relation]
  scope :created_by, ->(user) { AudioEventImport.where(creator: user) }

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  validates :name, presence: true, length: { minimum: 2 }

  def set_defaults
    self.files ||= []
  end

  def serialize_imported_events
    return [] if imported_events.blank?

    imported_events.map do |e|
      hash = e.as_json

      all_errors = errors.to_hash(true).map { |k, v|
        v.map do |msg|
          { id: k, title: msg }
        end
      }.flatten

      hash[:errors] = all_errors

      hash[:tags] = e.tags.map(&:as_json)

      hash
    end
  end

  def self.filter_settings
    common_fields = [
      :id, :name, :description, :files, :imported_events,
      :creator_id, :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at
    ]
    {
      valid_fields: common_fields,
      render_fields: common_fields + [:description_html_tagline, :description_html],
      text_fields: [:name, :description],
      custom_fields2: {
        **AudioEventImport.new_render_markdown_for_api_for(:description),
        imported_events: {
          query_attributes: [:id],
          transform: lambda { |item|
                       item.serialize_imported_events
                     },
          arel: nil,
          type: :hash
        }

      },
      new_spec_fields: lambda { |_user|
        {
          name: nil,
          description: nil,
          file_name: nil
        }
      },
      controller: :audio_event_imports,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :asc
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: AudioEventImport.arel_table[:id].eq(AudioEvent.arel_table[:audio_event_import_id]),
          available: true
        }
      ]
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
        files: {
          type: 'array',
          readOnly: true,
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              name: { type: 'string' },
              additional_tags: Api::Schema.ids(read_only: true),
              imported_at: Api::Schema.date(read_only: true)
            },
            readOnly: true
          }
        },
        # TODO: flush this out when we add an audio events schema
        imported_events: {
          type: 'array',
          readOnly: true,
          items: {
            properties: {
              errors: { type: 'array', readOnly: true }
            },
            readOnly: true
          }
        }
      },
      required: [
        :id,
        :name,
        :files,
        :imported_events,
        :description,
        :description_html,
        :description_html_tagline,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at
      ]
    }.freeze
  end
end
