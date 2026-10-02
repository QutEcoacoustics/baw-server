# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Table::Observation do
  describe '.mapping' do
    create_audio_recordings_hierarchy
    prepare_provenance

    subject(:observation) do
      row = table.mapping(tagging, deployment).ordered_values
      table.attribute_names.zip(row).to_h
    end

    let(:table) { BawWorkers::Export::CamtrapDp::Table::Observation }

    let(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
    let(:tagging) { create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user) }
    let(:deployment) { BawWorkers::Export::CamtrapDp::DeploymentAccumulator.new.add_or_update(tagging) }

    it 'maps the tagged interval and frequency bounds' do
      expect(observation).to include(
        observationID: tagging.global_identifier,
        deploymentID: site.global_identifier,
        mediaID: audio_recording.global_identifier,
        observationLevel: 'interval',
        observationType: 'animal',
        scientificName: tagging.tag.text,
        frequencyLow: audio_event.low_frequency_hertz,
        frequencyHigh: audio_event.high_frequency_hertz,
        classificationMethod: nil,
        classifiedBy: writer_user.full_name
      )
    end

    it 'maps machine classification details from audio event provenance' do
      audio_event.update!(provenance:)

      expect(observation).to include(classificationMethod: 'machine', classifiedBy: provenance.name)
    end

    it 'leaves the scientific name blank for a common-name tag' do
      tagging.tag.update!(type_of_tag: 'common_name')

      expect(observation).to include(observationType: 'animal', scientificName: nil)
    end
  end

  describe '.observation_type' do
    let(:observation_table) { BawWorkers::Export::CamtrapDp::Table::Observation }

    it 'maps taxonomic tags to animal', :aggregate_failures do
      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'species_name',
        text: 'Species test',
        is_taxonomic: true
      ))).to eq('animal')

      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'common_name',
        text: 'Common test',
        is_taxonomic: true
      ))).to eq('animal')
    end

    it 'maps known general tags to their observation types', :aggregate_failures do
      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'general',
        text: 'unknown'
      ))).to eq('unknown')

      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'general',
        text: 'Human Voice'
      ))).to eq('human')

      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'general',
        text: 'chainsaw'
      ))).to eq('vehicle')
    end

    it 'maps unmatched general tags to unclassified' do
      expect(observation_table.observation_type(build(
        :tag,
        type_of_tag: 'general',
        text: 'weather'
      ))).to eq('unclassified')
    end
  end
end
