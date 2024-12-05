# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_import_files
#
#  id                                                                                             :bigint           not null, primary key
#  additional_tag_ids(Additional tag ids applied for this import)                                 :integer          is an Array
#  file_hash(Hash of the file contents used for uniqueness checking)                              :text             not null
#  path(Path to the file on disk, relative to the analysis job item. Not used for uploaded files) :string
#  created_at                                                                                     :datetime         not null
#  analysis_jobs_item_id                                                                          :integer
#  audio_event_import_id                                                                          :integer          not null
#
# Indexes
#
#  index_audio_event_import_files_on_analysis_jobs_item_id  (analysis_jobs_item_id)
#  index_audio_event_import_files_on_audio_event_import_id  (audio_event_import_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_jobs_item_id => analysis_jobs_items.id) ON DELETE => cascade
#  fk_rails_...  (audio_event_import_id => audio_event_imports.id) ON DELETE => cascade
#

FactoryBot.define do
  factory :audio_event_import_file do
    created_at { Time.current }

    audio_event_import

    trait(:with_file) do
      after(:build) do |import_file|
        file = Rack::Test::UploadedFile.new(Fixtures.audio_check_csv, 'text/csv')
        import_file.file.attach(
          file
          # io: File.open(Fixtures.audio_check_csv),
          # filename: Fixtures.audio_check_csv.basename.to_s,
          # content_type: 'text/csv',
        )
      end
    end

    # this trait is problematic - the factory can't be made more than once
    # othewrwise it will fail the uniqueness constraint on the file_hash column
    trait(:with_path) do
      analysis_jobs_item
      # rubocop:disable RSpec
      path { Fixtures.audio_check_csv }
      # rubocop:enable RSpec
    end
  end
end
