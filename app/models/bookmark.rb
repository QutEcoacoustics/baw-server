# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                 :integer          not null, primary key
#  category           :string
#  description        :text
#  name               :string
#  offset_seconds     :decimal(10, 4)
#  created_at         :datetime
#  updated_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer          not null
#  updater_id         :integer
#
# Indexes
#
#  bookmarks_name_creator_id_uidx         (name,creator_id) UNIQUE
#  index_bookmarks_on_audio_recording_id  (audio_recording_id)
#  index_bookmarks_on_creator_id          (creator_id)
#  index_bookmarks_on_updater_id          (updater_id)
#
# Foreign Keys
#
#  bookmarks_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  bookmarks_creator_id_fk          (creator_id => users.id)
#  bookmarks_updater_id_fk          (updater_id => users.id)
#
class Bookmark < ApplicationRecord
  # relations
  belongs_to :audio_recording, inverse_of: :bookmarks

  belongs_to :creator, class_name: 'User', inverse_of: :created_bookmarks
  belongs_to :updater, class_name: 'User', inverse_of: :updated_bookmarks, optional: true

  # association validations
  #validates_associated :audio_recording
  #validates_associated :creator

  # attribute validations
  validates :offset_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :name, presence: true,
    uniqueness: { case_sensitive: false, scope: :creator_id, message: 'should be unique per user' }

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :audio_recording_id, :name, :category, :description, :offset_seconds, :created_at,
                     :creator_id, :updater_id, :updated_at],
      render_fields: [:id, :audio_recording_id, :name, :category, :description, :offset_seconds, :created_at,
                      :creator_id, :updater_id, :updated_at],
      text_fields: [:name, :description, :category],
      custom_fields: lambda { |item, _user|
        [item, item.render_markdown_for_api_for(:description)]
      },
      new_spec_fields: lambda { |_user|
        {
          name: nil,
          category: nil,
          description: nil,
          offset_seconds: nil
        }
      },
      controller: :bookmarks,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: AudioRecording,
          on: AudioRecording.arel_table[:id].eq(Bookmark.arel_table[:audio_recording_id]),
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
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        audio_recording_id: { '$ref' => '#/components/schemas/id' },
        name: { type: 'string' },
        category: { type: 'string' },
        offset_seconds: { type: 'number' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.updater_and_creator_user_stamps
      },
      required: [
        :id,
        :audio_recording_id,
        :name,
        :category,
        :offset_seconds,
        :description,
        :description_html,
        :description_html_tagline,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at
      ]
    }.freeze
  end
end
