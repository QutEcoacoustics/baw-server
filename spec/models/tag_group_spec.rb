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
