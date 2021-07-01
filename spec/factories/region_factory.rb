# frozen_string_literal: true

# == Schema Information
#
# Table name: regions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  name        :string
#  notes       :jsonb
#  created_at  :datetime
#  updated_at  :datetime
#  creator_id  :integer
#  deleter_id  :integer
#  project_id  :integer          not null
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :region do
    sequence(:name) { |n| "region name #{n}" }
    sequence(:description) { |n| "site **description** #{n}" }
    sequence(:notes) { |n| { "region_note_#{n}" => n } }

    project

    creator
  end
end
