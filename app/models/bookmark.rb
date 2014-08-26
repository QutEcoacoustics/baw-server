class Bookmark < ActiveRecord::Base
  attr_accessible :audio_recording_id, :name, :description, :offset_seconds, :category

  # relations
  belongs_to :audio_recording, inverse_of: :bookmarks

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_bookmarks
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_bookmarks

  # add created_at and updated_at stamper
  stampable

  # association validations
  validates :audio_recording, existence: true
  #validates :creator, existence: true

  # attribute validations
  validates :offset_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :audio_recording_id, presence: true
  validates :name, presence: true, uniqueness: {case_sensitive: false, scope: :creator_id, message: 'should be unique per user'}

  # model scopes
  scope :filter_by_name, lambda { |name| where(name: name) }
  scope :filter_by_category, lambda { |category| where(category: category) }

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:audio_recording_id, :offset_seconds, :name, :description, :category, :created_at],
        # :updated_at, :creator_id, :updater_id,
        text_fields: [:name, :description, :category],
        controller: :bookmarks,
        action: :filter,
        defaults: {
            order_by: :created_at,
            direction: :desc
        }
    }
  end

end