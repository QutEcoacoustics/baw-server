class Tag < ActiveRecord::Base
  extend Enumerize

  # attr
  attr_accessible :is_taxanomic, :text, :type_of_tag, :retired, :notes

  # relations
  has_many :taggings # no inverse of specified, as it interferes with through: association
  has_many :audio_events, through: :taggings
  belongs_to :user, class_name: 'User', foreign_key: :creator_id

  accepts_nested_attributes_for :audio_events

  # userstamp
  stampable

  # enums
  AVAILABLE_TYPE_OF_TAGS_SYMBOLS = [:general, :common_name, :species_name, :looks_like, :sounds_like]
  AVAILABLE_TYPE_OF_TAGS = AVAILABLE_TYPE_OF_TAGS_SYMBOLS.map{ |item| item.to_s }

  enumerize :type_of_tag, in: AVAILABLE_TYPE_OF_TAGS, predicates: true

  # validation
  validates :is_taxanomic, inclusion: { in: [true, false] }
  validates :text, uniqueness: { case_sensitive: false }, presence: true
  validates :retired, inclusion: { in: [true, false] }
  validates :type_of_tag, inclusion: {in: AVAILABLE_TYPE_OF_TAGS}, presence: true

  # http://stackoverflow.com/questions/11569940/inclusion-validation-fails-when-provided-a-symbol-instead-of-a-string
  # this lets a symbol be set, and it all still works
  def type_of_tag=(new_type_of_tag)
    super new_type_of_tag.to_s
  end

end
