# frozen_string_literal: true

describe Export::CamtrapDpOptionsContract do
  subject(:contract) { Export::CamtrapDpOptionsContract.new }

  let(:valid_options) do
    {
      contributors: [{ title: 'Alice', path: 'https://example.com/alice' }],
      project_capture_method: ['continuous'],
      project_sampling_design: 'systematicRandom',
      emit_project_license: true,
      forced_timezone: 'Australia/Brisbane'
    }
  end

  it 'accepts valid options' do
    expect(contract.call(valid_options)).to be_success
  end

  it 'rejects empty options' do
    expect(contract.call({})).to be_failure
  end

  it 'rejects an unknown capture method' do
    expect(contract.call(valid_options.merge(project_capture_method: ['invalid']))).to be_failure
  end

  it 'rejects an unknown sampling design' do
    expect(contract.call(valid_options.merge(project_sampling_design: 'invalid'))).to be_failure
  end

  it 'rejects a contributor without a title' do
    expect(contract.call(valid_options.merge(contributors: [{ role: 'contact' }]))).to be_failure
  end

  it 'rejects an invalid forced timezone' do
    expect(contract.call(valid_options.merge(forced_timezone: 'invalid'))).to be_failure
  end

  it 'rejects emit_project_license when it is the string "false"' do
    expect(contract.call(valid_options.merge(emit_project_license: 'false'))).to be_failure
  end

  it 'rejects emit_project_license when it is the integer 1' do
    expect(contract.call(valid_options.merge(emit_project_license: 1))).to be_failure
  end

  it 'accepts emit_project_license when it is false' do
    expect(contract.call(valid_options.merge(emit_project_license: false))).to be_success
  end
end
