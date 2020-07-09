# frozen_string_literal: true

class TagGroup < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  belongs_to :tag, inverse_of: :tag_groups
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_tags

  # association validations
  validates_associated :creator
  validates_associated :tag
  validates :group_identifier, presence: true
  validates_uniqueness_of :group_identifier, scope: [:tag_id], case_sensitive: false
end
