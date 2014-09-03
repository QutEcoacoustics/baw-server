class AudioEventComment < ActiveRecord::Base
  extend Enumerize
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessible :audio_event_id, :comment, :flag, :flag_explain

  belongs_to :audio_event, inverse_of: :comments
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_event_comments
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_event_comments
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_event_comments
  belongs_to :flagger, class_name: 'User', foreign_key: 'flagger_id', inverse_of: :flagged_audio_event_comments

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # enums
  AVAILABLE_FLAGS_SYMBOLS = [:report]
  AVAILABLE_FLAGS = AVAILABLE_FLAGS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_FLAGS_DISPLAY = [
      {id: :report, name: 'Report'},
  ]

  enumerize :flag, in: AVAILABLE_FLAGS, predicates: true

  # association validations
  validates :audio_event, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :comment, presence: true, length: {minimum: 2}

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :audio_event_id, :comment, :flag, :flag_explain, :flagged_at, :created_at, :creator_id],
        render_fields: [:id, :audio_event_id, :comment, :flag, :creator_id],
        text_fields: [:comment, :flag, :flag_explain],
        controller: :audio_event_comments,
        action: :filter,
        defaults: {
            order_by: :created_at,
            direction: :desc
        }
    }
  end
end