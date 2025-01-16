# frozen_string_literal: true

describe BawWorkers::Jobs::Harvest::HarvestJob, :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  prepare_harvest_with_mappings do
    [
      BawWorkers::Jobs::Harvest::Mapping.new(
        path: '',
        site_id: site.id,
        utc_offset: nil,
        recursive: false
      )
    ]
  end

  pause_all_jobs

  before do
    clear_original_audio
    clear_harvester_to_do
  end

  describe 'special characters in filenames' do
    it 'works with filenames that have non-printable characters' do
      paths = copy_fixture_to_harvest_directory(
        Fixtures.audio_file_mono,
        harvest,
        target_name: Fixtures::MIXED_ENCODING_FILENAME
      )

      BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(harvest, paths.harvester_relative_path, should_harvest: true)

      perform_jobs(count: 1)

      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

      item = HarvestItem.first

      # so in this case extra characters are stuck in between the datestamp
      # so the harvest should not be exceptional
      # but the file should not he harvested and should record validation errors
      aggregate_failures do
        expect(item).to be_failed
        expect(item.info.to_h[:validations]).to eq [
          # and also a more helpful validation about the encoding
          {
            name: :invalid_filename_characters,
            status: :fixable,
            message: 'Filename has invalid characters. Remove problem characters where indicated `20231205T��140158_TURTNEST22_n1_m1.wav`'
          }
        ]
      end
    end

    it 'works for files that have invalid UTF-8 byte sequences in them' do
      paths = copy_fixture_to_harvest_directory(
        Fixtures.audio_file_mono,
        harvest
      )

      bad_name = "\xC2.wav"

      # have to rename here because Pathname is a nanny and won't let you create files with invalid UTF-8 sequences
      File.rename(
        paths.absolute_path.to_s,
        "#{harvest.upload_directory}/#{bad_name}"
      )

      BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
        harvest,
        paths.harvester_relative_path.to_s.gsub(Fixtures.audio_file_mono.basename.to_s, bad_name),
        should_harvest: true
      )

      perform_jobs(count: 1)

      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

      item = HarvestItem.first

      # in this case the file is actually renamed before the harvest job starts
      expect(item.path).to match(/�.wav/)

      # so in this case extra characters are stuck in between the datestamp
      # so the harvest should not be exceptional
      # but the file should not he harvested and should record validation errors
      aggregate_failures do
        expect(item).to be_failed
        expect(item.info.to_h[:validations]).to eq [
          # and also a more helpful validation about the encoding
          {
            name: :invalid_filename_characters,
            status: :fixable,
            message: 'Filename has invalid characters. Remove problem characters where indicated `�.wav`'
          }
        ]
      end
    end
  end
end
