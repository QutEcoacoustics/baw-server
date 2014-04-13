class AudioEventComment < ActiveRecord::Base
  extend Enumerize
  attr_accessible :comment, :flag, :audio_event_id, :creator_id, :updater_id, :deleter_id, :deleted_at, :flagger_id, :flagged_at
  attr_readonly :audio_event_id, :creator_id, :updater_id, :deleter_id, :deleted_at, :flagger_id, :flagged_at

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id

  belongs_to :audio_event, inverse_of: :AudioEventComment

  stampable
  acts_as_paranoid

  # enums
  AVAILABLE_FLAGS_SYMBOLS = [:report]
  AVAILABLE_FLAGS = AVAILABLE_FLAGS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_FLAGS_DISPLAY = [
      {id: :report, name: 'Report'},
  ]

  enumerize :flag, in: AVAILABLE_FLAGS, predicates: true

  # validations
  validates :comment, presence: true, length: {minimum: 2}

  def self.filtered(params)

    query = AudioEventComment.include(:audio_event)

    page = AudioEventComment.filter_count(params, :page, 1, nil)
    items = AudioEventComment.filter_count(params, :items, 1, 30)
    query = query.offset((page - 1) * items).limit(items)
    query = query.order('audio_event_comments.created_at DESC')
    puts query.to_sql
    query
  end

end
