# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id                                                     :bigint           not null, primary key
#  download_count                                         :integer          default(0)
#  error(User visible error message if the export failed) :text
#  expires_at                                             :datetime
#  export_type                                            :string(16)       not null
#  filter                                                 :jsonb            not null
#  finished_at                                            :datetime
#  name                                                   :string
#  obfuscate_locations                                    :boolean
#  options(Additional options for the export)             :jsonb
#  purged                                                 :boolean
#  started_at                                             :datetime
#  status                                                 :enum             default("pending"), not null
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#  creator_id                                             :bigint           not null
#  project_id                                             :bigint           not null
#
# Indexes
#
#  index_exports_on_creator_id  (creator_id)
#  index_exports_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :export do
    sequence(:name) { |n| "export_#{n}" }

    obfuscate_locations { false }
    export_type { 'camtrap_dp' }

    filter { {} }
    options { {} }

    status { 'pending' }

    started_at { nil }
    finished_at { nil }
    expires_at { nil }

    error { nil }
    purged { nil }

    download_count { 0 }

    created_at { nil }
    updated_at { nil }

    creator
    project

    trait :with_archive do
      after(:build) do |export|
        archive = Rack::Test::UploadedFile.new(Fixtures.zip_fixture, 'application/zip')
        export.archive.attach(archive)
      end
    end
  end
end
