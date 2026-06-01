# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Exporter do
  create_entire_hierarchy
  subject(:exporter) do
    BawWorkers::Export::CamtrapDp::Exporter.new(
      filter, **export_options
    )
  end

  let(:export_options) do
    {
      contributors: [{ title: 'Alice' }],
      should_obfuscate: true,
      project_capture_method: ['continuous', 'recordingSchedule'],
      project_individual_animals: false,
      observation_level: ['media'],
      project_sampling_design: 'systematicRandom',
      project_title: 'My Project'
    }
  end

  let(:filter) {
    Tagging.joins(:tag).where(tags: { type_of_tag: 'species_name', is_taxonomic: true })
  }
  let(:datapackage) { JSON.parse(File.read(exporter.files.fetch(:datapackage))) }
  let(:observations) { CSV.read(exporter.files.fetch(:observations), headers: true) }
  let(:deployments) { CSV.read(exporter.files.fetch(:deployments), headers: true) }
  let(:media) { CSV.read(exporter.files.fetch(:media), headers: true) }

  before do
    create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user)
  end

  context 'with valid inputs' do
    it { is_expected.to be_a(BawWorkers::Export::CamtrapDp::Exporter) }
  end

  context 'with invalid filter object' do
    let(:filter) { 'not a relation' }

    it { expect { subject }.to raise_error(ArgumentError, 'Expected filter to be ActiveRecord::Relation') }
  end

  context 'with a missing Tagging relation on filter' do
    let(:filter) { AudioEvent.all }

    it { expect { subject }.to raise_error(ArgumentError, /Expected filter to be Tagging relation/) }
  end

  it 'runs' do
    expect { subject.call }.not_to raise_error
  end

  it 'returns a manifest' do
    result = subject.call
    expect(result).to have_key(:manifest)
    expect(result[:manifest]).to have_key(:zip_path)
    expect(result[:manifest][:zip_path]).to be_a(Pathname)
  end

  context 'when forced obfuscation is disabled' do
    let(:export_options) { super().merge(should_obfuscate: false) }

    it 'writes real coordinates' do
      subject.call
      debugger

      expect(deployments.first.to_h).to include(
        'latitude' => site.latitude.to_s,
        'longitude' => site.longitude.to_s
      )
    end
  end
end

# to test the file name stuff?
# link_original_audio_to_audio_recordings(audio_recording, target: Fixtures.audio_file_mono)
