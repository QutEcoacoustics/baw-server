# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id              :bigint           not null, primary key
#  mappings        :jsonb
#  state           :string
#  streaming       :boolean
#  upload_password :string
#  upload_user     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :integer
#  project_id      :integer          not null
#  updater_id      :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :harvest do
    streaming { false }

    project
    creator
  end
end
