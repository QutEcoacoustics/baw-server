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

  # add created_at and updated_at stamper
  stampable

  # enums
  AVAILABLE_TYPE_OF_TAGS_SYMBOLS = [:general, :common_name, :species_name, :looks_like, :sounds_like]
  AVAILABLE_TYPE_OF_TAGS = AVAILABLE_TYPE_OF_TAGS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_TYPE_OF_TAGS_DISPLAY = [
      {id: :general, name: 'General'},
      {id: :common_name, name: 'Common Name'},
      {id: :species_name, name: 'Scientific Name'},
      {id: :looks_like, name: 'Looks like'},
      {id: :sounds_like, name: 'Sounds Like'},
  ]

  enumerize :type_of_tag, in: AVAILABLE_TYPE_OF_TAGS, predicates: true

  # association validations
  validates :creator, existence: true

  # attribute validations
  validates :is_taxanomic, inclusion: {in: [true, false]}
  validates :text, uniqueness: {case_sensitive: false}, presence: true
  validates :retired, inclusion: {in: [true, false]}
  validates_presence_of :type_of_tag
  validate :taxonomic_enforced

  # http://stackoverflow.com/questions/11569940/inclusion-validation-fails-when-provided-a-symbol-instead-of-a-string
  # this lets a symbol be set, and it all still works
  def type_of_tag=(new_type_of_tag)
    super new_type_of_tag.to_s
  end

  # order by number of audio recordings associated with a tag
  #Tag.joins(:taggings).select('tags.*, count(tag_id) as "tag_count"').group(:tag_id).order(' tag_count desc')

  def taxonomic_enforced
    if self.type_of_tag == 'common_name' || self.type_of_tag == 'species_name'
      errors.add(:is_taxanomic, "must be true for #{self.type_of_tag}") unless self.is_taxanomic
    else
      errors.add(:is_taxanomic, "must be false for #{self.type_of_tag}") if self.is_taxanomic
    end

  end

  # @param [Tag] tags
  def self.get_priority_tag(tags)

    return nil if tags.size < 1

    first = tags.first
    return first if first.type_of_tag.to_s == 'common_name'

    first_common = nil
    first_species = nil
    first_other = nil
    tags.each do |tag|
      first_common = tag if tag.type_of_tag == 'common_name' && first_common == nil
      first_species = tag if tag.type_of_tag == 'species_name' && first_common == nil
      first_other = tag if first_other == nil
    end

    first_common || first_species || first_other
  end

end
