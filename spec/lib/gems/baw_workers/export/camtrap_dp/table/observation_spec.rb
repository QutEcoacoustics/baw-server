# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Table::Observation do
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
