class Tag < ActiveRecord::Base
  extend Enumerize

  # attr
  attr_accessible :is_taxanomic, :text, :type_of_tag, :retired, :notes

  # relations
  has_many :taggings # no inverse of specified, as it interferes with through: association
  has_many :audio_events, through: :taggings
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_tags
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_tags

  accepts_nested_attributes_for :audio_events

  # userstamp
  stampable

  # enums
  AVAILABLE_TYPE_OF_TAGS_SYMBOLS = [:general, :common_name, :species_name, :looks_like, :sounds_like]
  AVAILABLE_TYPE_OF_TAGS = AVAILABLE_TYPE_OF_TAGS_SYMBOLS.map{ |item| item.to_s }

  AVAILABLE_TYPE_OF_TAGS_DISPLAY = [
      { id: :general, name: 'General'},
      { id: :common_name, name: 'Common Name'},
      { id: :species_name, name: 'Scientific Name'},
      { id: :looks_like, name: 'Looks like'},
      { id: :sounds_like, name: 'Sounds Like'},
  ]

  enumerize :type_of_tag, in: AVAILABLE_TYPE_OF_TAGS, predicates: true

  # validation
  validates :is_taxanomic, inclusion: { in: [true, false] }
  validates :text, uniqueness: { case_sensitive: false }, presence: true
  validates :retired, inclusion: { in: [true, false] }
  validates_presence_of :type_of_tag

  # http://stackoverflow.com/questions/11569940/inclusion-validation-fails-when-provided-a-symbol-instead-of-a-string
  # this lets a symbol be set, and it all still works
  def type_of_tag=(new_type_of_tag)
    super new_type_of_tag.to_s
  end

  # order by number of audio recordings associated with a tag
  #Tag.joins(:taggings).select('tags.*, count(tag_id) as "tag_count"').group(:tag_id).order(' tag_count desc')

end
