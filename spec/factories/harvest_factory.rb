# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id                      :bigint           not null, primary key
#  last_mappings_change_at :datetime
#  last_metadata_review_at :datetime
#  last_upload_at          :datetime
#  mappings                :jsonb
#  name                    :string
#  status                  :string
#  streaming               :boolean
#  upload_password         :string
#  upload_user             :string
#  upload_user_expiry_at   :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  creator_id              :integer
#  project_id              :integer          not null
#  updater_id              :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :harvest do
    streaming { false }

    association :project, :with_uploads_enabled
    creator
  end
end
