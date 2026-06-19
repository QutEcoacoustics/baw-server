# frozen_string_literal: true

require(Rails.root / 'spec' / 'support' / 'shared_context' / 'rake_context')

describe 'baw:camtrap_dp:update' do
  include_context 'rake_spec_context'
  its(:prerequisites) { is_expected.to include('download', 'refresh_profile') }
end

describe 'baw:camtrap_dp:download' do
  include_context 'rake_spec_context'

  let(:log_io) { StringIO.new }

  before do
    allow(Logger).to receive(:new).and_return(Logger.new(log_io))
  end

  its(:prerequisites) { is_expected.to include(BawWorkers::Export::CamtrapDp::Profile::DIRECTORY.to_s) }

  it 'logs and prints the result of Profile.download' do
    allow(BawWorkers::Export::CamtrapDp::Profile).to receive(:download).and_return({ fake: 'result' })

    expect { subject.invoke }.to output(/Downloaded profile assets:\n\{fake: "result"\}/m).to_stdout

    expect(log_io.string).to include('{fake: "result"}')
  end
end

describe 'baw:camtrap_dp:refresh_profile' do
  include_context 'rake_spec_context'

  its(:prerequisites) { is_expected.to include(BawWorkers::Export::CamtrapDp::Profile::LOCAL_VALIDATION_PROFILE_PATH.to_s) }
end

describe BawWorkers::Export::CamtrapDp::Profile::LOCAL_VALIDATION_PROFILE_PATH.to_s do
  include_context 'rake_spec_context'

  let(:log_io) { StringIO.new }

  before do
    allow(Logger).to receive(:new).and_return(Logger.new(log_io))
  end

  its(:prerequisites) { is_expected.to include(BawWorkers::Export::CamtrapDp::Profile::PROFILE_PATH.to_s) }

  it 'logs and prints the result of Profile.create_local_validation_profile' do
    allow(BawWorkers::Export::CamtrapDp::Profile).to receive(:create_local_validation_profile).and_return({ local: 'profile' })

    expect { subject.execute }.to output(/Created local validation profile:\n\{local: "profile"\}/m).to_stdout

    expect(log_io.string).to include('{local: "profile"}')
  end
end
