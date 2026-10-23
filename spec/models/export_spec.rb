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
require 'rails_helper'

describe Export do
  subject(:export) { build(:export, :with_zip_file, filter: filter) }

  let(:filter) { {} }

  it { is_expected.to be_valid }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_attributes(status: 'pending', download_count: 0) }
  it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(255) }
  it { is_expected.to validate_presence_of(:export_type) }

  describe '#validate' do
    let(:errors) { export.tap(&:validate).errors }

    it 'adds an error to file when the attached file does not have the zip content type' do
      export.file.blob.content_type = 'application/none'

      expect(errors[:file]).to eq(['must be a zip file'])
    end

    it 'adds an error to options when a camtrap_dp option has a value that is not allowed' do
      export.options = { project_capture_method: ['invalid'] }

      expect(errors[:options]).to include(
        'project_capture_method.0 must be one of: activityDetection, continuous, recordingSchedule'
      )
    end

    context 'when obfuscate_locations is false' do
      before { export.obfuscate_locations = false }

      it 'is not valid if the creator is not the project owner' do
        expect(errors[:obfuscate_locations]).to eq(['can only be set to false by the project owner'])
      end
    end

    context 'when filter is nil' do
      let(:filter) { nil }

      it 'is not valid' do
        expect(errors[:filter]).to include('cannot be nil')
      end
    end

    context 'when filter contains outer keys' do
      let(:filter) { { filter: {} } }

      it 'is not valid' do
        expect(errors[:filter]).to include(
            'must be an inner filter, cannot contain any of filter, projection, paging, sorting'
          )
      end
    end

    context 'with invalid filter syntax' do
      let(:filter) { { invalid: true } }

      it 'is not valid' do
        expect(errors[:filter]).to include(
          'Filter parameters were not valid: Unrecognized combiner or field name `invalid`.'
        )
      end
    end
  end

  describe '#build_generator' do
    it 'returns a generator that responds to call and filter_as_relation for every export type' do
      Export.export_types.each_key do |type|
        generator = build(:export, export_type: type).send(:build_generator)

        expect(generator).to respond_to(:call, :filter_as_relation)
      end
    end
  end

  describe '#generate' do
    create_entire_hierarchy

    let(:export) {
      create(:export, creator: owner_user, project:, options: options, filter: filter)
    }

    let(:exporter) { BawWorkers::Export::CamtrapDp::Exporter }

    let(:options) {
      {
        contributors: [{ title: 'Alice', path: 'http://www.test' }],
        project_capture_method: ['continuous', 'recordingSchedule'],
        project_sampling_design: 'systematicRandom',
        emit_project_license: true
      }
    }

    let(:now) { Time.utc(2026, 7, 29, 3, 50, 44) }

    around { |example| Timecop.freeze(now) { example.run } }

    context 'when successful' do
      it 'marks the export ready with a zip file attached' do
        export.generate

        expect(export).to have_attributes(
          status: 'ready', error: nil, started_at: now, finished_at: now, expires_at: now + 7.days,
          file: have_attributes(content_type: 'application/zip', filename: have_attributes(extension: 'zip'))
        )
      end
    end

    context 'when filtering conditions span multiple projects' do
      let(:other_project) { create(:project, creator: owner_user) }
      let(:other_site) { create(:site_with_lat_long, creator: owner_user, projects: [other_project], region: nil) }
      let(:other_recording) { create(:audio_recording, site: other_site, creator: owner_user, uploader: owner_user) }
      let(:filter) { { 'audio_events.audio_recording_id': { in: [audio_recording.id, other_recording.id] } } }

      let(:exported_observations) {
        zip = Zip::File.open_buffer(export.file.download)
        csv = zip.read('observations.csv')
        CSV.parse(csv, headers: true).pluck('observationID')
      }

      before do
        other_event = create(:audio_event, audio_recording: other_recording, creator: owner_user)
        create(:tagging, audio_event: other_event, tag: tag, creator: owner_user)
      end

      it 'only exports taggings from the project scope' do
        export.generate

        # The creator owns both projects, so the other project's tagging would be
        # exported, if exports were not correctly project scoped.
        expect(exported_observations).not_to be_empty
        expect(exported_observations).to all(end_with("/taggings/#{tagging.id}"))
      end
    end

    context 'when the exporter raises a CamtrapDpError' do
      it 'records the failure without raising' do
        allow(exporter).to receive(:new).and_raise(BawWorkers::Export::CamtrapDp::Errors::ValidationError, 'bad data')

        expect { export.generate }.not_to raise_error
        expect(export.reload).to have_attributes(status: 'failed', error: 'bad data', finished_at: now)
      end
    end

    context 'when the exporter raises an unexpected error' do
      it 'records a generic failure and re-raises' do
        allow(exporter).to receive(:new).and_raise(StandardError, 'secret detail')

        expect { export.generate }.to raise_error(StandardError, 'secret detail')
        expect(export.reload).to have_attributes(
          status: 'failed', error: 'An unexpected error occurred while generating the export.'
        )
      end
    end

    context 'when saving the failure also raises a database error' do
      it 'raises the original error' do
        allow(exporter).to receive(:new).and_raise(StandardError, 'original')
        allow(export).to receive(:update_columns).and_raise(ActiveRecord::ActiveRecordError, 'db down')

        expect { export.generate }.to raise_error(StandardError, 'original')
      end
    end

    context 'when the export produces no file' do
      it 'raises an error and records the export as failed' do
        allow(exporter).to receive(:new).and_return(instance_double(exporter, call: nil))

        expect { export.generate }.to raise_error(Export::InvalidTransition, /without a file/)
        expect(export.reload).to have_attributes(status: 'failed', file: be_blank)
      end
    end

    context 'when the export is already working' do
      let(:export) { super().tap { |e| e.update!(status: 'working') } }

      it 'returns without generating and leaves the export unchanged' do
        expect { export.generate }.not_to(change { export.reload.attributes })
        expect(export).to have_attributes(status: 'working', file: be_blank)
      end

      context 'when resume is true' do
        it 'generates the export and updates the status to ready' do
          export.generate(resume: true)

          expect(export.reload).to have_attributes(status: 'ready', error: nil)
        end
      end
    end

    context 'when the export is already ready' do
      it 'returns without generating and leaves the export unchanged' do
        export.generate
        export.update!(finished_at: 1.day.ago)

        expect { export.generate }.not_to(change { export.reload.attributes })
        expect(export).to have_attributes(status: 'ready', file: be_attached)
      end
    end

    context 'when an export is failed' do
      it 'clears the previous error and generates the export' do
        export.update!(status: 'failed', error: 'old error', finished_at: 1.hour.ago)

        export.generate

        expect(export.reload).to have_attributes(status: 'ready', error: nil, started_at: now, finished_at: now)
      end
    end
  end

  describe '#enqueue!' do
    let(:export) { create(:export) }

    let(:job_class) { BawWorkers::Jobs::Export::ExportJob }

    before { allow(job_class).to receive(:enqueue) }

    it 'marks the export queued and enqueues the job' do
      export.enqueue!

      expect(export.reload.status).to eq('queued')
      expect(job_class).to have_received(:enqueue).with(export)
    end

    it 're-enqueues a failed export and clears the previous failure' do
      export.update!(status: 'failed', error: 'old error', finished_at: 1.hour.ago)

      export.enqueue!

      expect(export.reload).to have_attributes(status: 'queued', error: nil, finished_at: nil)
    end

    it 'raises an error and does not enqueue a job for a ready export' do
      export.update!(status: 'ready')

      expect { export.enqueue! }.to raise_error(Export::InvalidTransition, 'Cannot transition from ready to queued')
      expect(export.reload.status).to eq('ready')
      expect(job_class).not_to have_received(:enqueue)
    end

    it 'leaves the export unchanged when the job fails to enqueue' do
      allow(job_class).to receive(:enqueue).and_raise(BawWorkers::ActiveJob::EnqueueError)

      expect { export.enqueue! }.to raise_error(BawWorkers::ActiveJob::EnqueueError)
      expect(export.reload.status).to eq('pending')
    end

    it 'enqueues a purged export and sets purged back to false' do
      export.update!(status: 'ready', purged: true)

      export.enqueue!

      expect(export.reload).to have_attributes(status: 'queued', purged: false)
    end
  end

  describe '#purge!' do
    let(:export) { create(:export, :with_zip_file, status: 'ready') }

    it 'removes the file and marks the export purged' do
      export.purge!

      expect(export.reload).to have_attributes(purged: true, status: 'ready', file: be_blank)
    end

    it 'does not change anything when the export is already purged' do
      export.purge!

      expect { export.purge! }.not_to(change { export.reload.attributes })
    end

    ['queued', 'working'].each do |status|
      it "refuses to purge an export that is #{status}" do
        earlier_copy = Export.find(export.id)
        export.update!(status:)

        expect { earlier_copy.purge! }.to raise_error(
          Export::InvalidTransition, "Cannot purge an export that is #{status}"
        )
        expect(export.reload).to have_attributes(purged: be_falsey, file: be_attached)
      end
    end
  end
end
