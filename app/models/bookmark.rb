class Bookmark < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  belongs_to :audio_recording, inverse_of: :bookmarks

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_bookmarks
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_bookmarks

  # association validations
  validates :audio_recording, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :offset_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :audio_recording_id, presence: true
  validates :name, presence: true, uniqueness: {case_sensitive: false, scope: :creator_id, message: 'should be unique per user'}

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :audio_recording_id, :name, :category, :description, :offset_seconds, :created_at, :creator_id],
        render_fields: [:id, :audio_recording_id, :name, :category, :description, :offset_seconds, :creator_id],
        text_fields: [:name, :description, :category],
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

end