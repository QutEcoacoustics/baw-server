# frozen_string_literal: true

require(Rails.root / 'spec' / 'support' / 'shared_context' / 'rake_context')

describe 'baw:camtrap_dp:update' do
  include_context 'rake_spec_context'

  before do
    allow(File).to receive(:write)
  end

  let(:expected_readme_output) do
    /# Downloaded profile assets:\n\n\{downloaded: "assets"\}.*# Created local validation profile:\n\n\{local: "profile"\}/m
  end

  it 'downloads the assets, builds the local validation profile, and writes the README' do
    allow(BawWorkers::Export::CamtrapDp::Profile).to receive(:download).and_return({ downloaded: 'assets' })
    allow(BawWorkers::Export::CamtrapDp::Profile).to receive(:create_local_validation_profile).and_return({ local: 'profile' })

    expect { subject.invoke }.to output(expected_readme_output).to_stdout

    expect(BawWorkers::Export::CamtrapDp::Profile).to have_received(:download)
    expect(BawWorkers::Export::CamtrapDp::Profile).to have_received(:create_local_validation_profile)

    expect(File).to have_received(:write).with(
      BawWorkers::Export::CamtrapDp::Profile::README_PATH,
      a_string_matching(expected_readme_output)
    )
  end
end
