# frozen_string_literal: true

# == Schema Information
#
# Table name: tag_groups
#
#  id               :integer          not null, primary key
#  group_identifier :string(255)      not null
#  created_at       :datetime         not null
#  creator_id       :integer          not null
#  tag_id           :integer          not null
#
# Indexes
#
#  index_tag_groups_on_tag_id  (tag_id)
#  tag_groups_uidx             (tag_id,group_identifier) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tag_id => tags.id)
#
class TagGroup < ApplicationRecord
  # relations
  belongs_to :tag, inverse_of: :tag_groups
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_tags

  # association validations
  # validates_associated :creator
  # validates_associated :tag
  validates :group_identifier, presence: true
  validates_uniqueness_of :group_identifier, scope: [:tag_id], case_sensitive: false
end
