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
#  project_id                                             :bigint
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
  subject { build(:export, :camtrap_dp) }

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:project).optional(true) }

  it 'defaults to the status pending with a download count of 0' do
    expect(subject).to have_attributes(status: 'pending', download_count: 0)
  end

  describe 'attachment' do
    subject { build(:export, :camtrap_dp, :with_zip_file) }

    it { is_expected.to be_valid }

    it 'does not allow an invalid attachment' do
      subject.file.blob.update(content_type: 'application/none')

      expect(subject).not_to be_valid
      expect(subject.errors[:file]).to include('must be a zip file')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(255) }
    it { is_expected.to validate_presence_of(:export_type) }
    it { is_expected.to validate_presence_of(:filter) }

    it 'is not valid with invalid camtrap_dp options' do
      export = build(:export, :camtrap_dp, creator: create(:user), options: { project_capture_method: ['invalid'] })

      expect(export).not_to be_valid
      expect(export.errors[:options]).to include(
        'project_capture_method.0 must be one of: activityDetection, continuous, recordingSchedule'
      )
    end

    context 'when obfuscate_locations is false' do
      subject { build(:export, :camtrap_dp, obfuscate_locations: false) }

      it 'is not valid if the creator is not the project owner' do
        expect(subject).not_to be_valid
        expect(subject.errors[:obfuscate_locations]).to include('can only be set to false by the project owner')
      end
    end
  end

  describe '#generate' do
    create_entire_hierarchy

    let(:export) {
      options = {
        contributors: [{ title: 'Alice', path: 'http://www.test' }],
        project_capture_method: ['continuous', 'recordingSchedule'],
        project_sampling_design: 'systematicRandom',
        emit_project_license: true,
        forced_timezone: nil
      }

      filter = { and: [{ 'sites.id': { in: [site.id] } }] }

      create(:export, :camtrap_dp, name: 'Test Export', creator: owner_user, options: options, filter: filter,
        project: project)
    }

    let(:generated_at) { Time.utc(2026, 7, 29, 3, 50, 44) }

    around do |example|
      Timecop.freeze(generated_at)

      example.run
    ensure
      Timecop.return
    end

    context 'when successful' do
      subject(:generated) { export.tap(&:generate) }

      it 'marks the export ready with a zip file attached', :aggregate_failures do
        expect(generated).to have_attributes(
          status: 'ready', started_at: generated_at, finished_at: generated_at, error: nil
        )
        expect(generated.file).to be_attached
        expect(generated.file.blob).to have_attributes(
          content_type: 'application/zip',
          filename: have_attributes(extension: 'zip')
        )
      end
    end

    context 'when the exporter raises a CamtrapDpError' do
      before do
        allow(BawWorkers::Export::CamtrapDp::Exporter).to receive(:new)
          .and_raise(BawWorkers::Export::CamtrapDp::Errors::ValidationError, 'bad data')
      end

      it 'records the failure without raising' do
        expect { export.generate }.not_to raise_error
        expect(export.reload).to have_attributes(status: 'failed', error: 'bad data', finished_at: generated_at)
      end
    end

    context 'when the exporter raises an unexpected error' do
      before do
        allow(BawWorkers::Export::CamtrapDp::Exporter).to receive(:new).and_raise(StandardError, 'secret detail')
      end

      it 'records a generic failure and re-raises' do
        expect { export.generate }.to raise_error(StandardError, 'secret detail')
        expect(export.reload).to have_attributes(
          status: 'failed',
          error: 'An unexpected error occurred while generating the export.'
        )
      end
    end

    context 'when another worker has started generating the export since this copy was loaded' do
      # `earlier_copy` still has the status `queued`, but the database row is already `working`.
      let(:earlier_copy) { Export.find(export.id) }

      before do
        export.update!(status: 'queued')
        earlier_copy
        export.update!(status: 'working')
        allow(BawWorkers::Export::CamtrapDp::Exporter).to receive(:new).and_call_original
      end

      it 'does not generate the export a second time' do
        expect(earlier_copy.generate).to be_nil
        expect(BawWorkers::Export::CamtrapDp::Exporter).not_to have_received(:new)
        expect(export.reload).to have_attributes(status: 'working')
        expect(export.file).not_to be_attached
      end
    end

    context 'when the export is already ready' do
      before do
        export.generate
        export.update!(finished_at: 1.day.ago)
      end

      it 'returns without generating and leaves the export unchanged' do
        expect { export.generate }.not_to(change { export.reload.attributes })
        expect(export.status).to eq('ready')
        expect(export.file).to be_attached
      end
    end

    context 'when retrying a failed export' do
      before { export.update!(status: 'failed', error: 'old error', finished_at: 1.hour.ago) }

      it 'clears the previous error and ends with the status ready' do
        export.generate

        expect(export.reload).to have_attributes(
          status: 'ready', error: nil, started_at: generated_at, finished_at: generated_at
        )
      end
    end

    context 'when resume is true and the export is already working' do
      before { export.update!(status: 'working') }

      it 'generates the export and ends with the status ready' do
        export.generate(resume: true)

        expect(export.reload).to have_attributes(status: 'ready', error: nil)
      end
    end

    context 'when the exporter produces no file' do
      before do
        allow(export).to receive(:build_generator).and_return(-> {})
      end

      it 'raises an error and records the export as failed instead of ready' do
        expect { export.generate }.to raise_error(Export::InvalidTransition, /without a file/)
        expect(export.reload).to have_attributes(status: 'failed', file: be_blank)
      end
    end

    context 'when recording a failure also fails' do
      before do
        allow(BawWorkers::Export::CamtrapDp::Exporter).to receive(:new).and_raise(StandardError, 'original')
        allow(export).to receive(:update_columns).and_raise(ActiveRecord::ActiveRecordError, 'db down')
      end

      it 'raises the original error, not the database error from saving the failure' do
        expect { export.generate }.to raise_error(StandardError, 'original')
      end
    end

    context 'when project is missing' do
      before { export.update!(project: nil) }

      it 'saves the error and records the export as failed' do
        export.generate

        expect(export.reload).to have_attributes(status: 'failed', error: 'project must be present')
      end
    end
  end

  describe '#enqueue!' do
    subject(:export) { create(:export, :camtrap_dp) }

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
    subject(:export) { create(:export, :camtrap_dp, :with_zip_file, status: 'ready') }

    it 'removes the file and marks the export purged' do
      export.purge!

      expect(export.reload).to have_attributes(purged: true, status: 'ready')
      expect(export.file).not_to be_attached
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
        expect(export.reload.purged).to be_falsey
        expect(export.file).to be_attached
      end
    end
  end
end
