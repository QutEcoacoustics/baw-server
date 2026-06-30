# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Table::Observation do
  create_entire_hierarchy

  context 'observation type mapping' do
    let(:observation_table) { BawWorkers::Export::CamtrapDp::Table::Observation }
    let(:tagging) { create(:tagging, audio_event:, tag:, creator: writer_user) }
    let(:mapping) { observation_table.mapping(tagging) }

    context 'with a species name tag' do
      let(:tag) { create(:tag, type_of_tag: 'species_name', text: 'Species test', is_taxonomic: true) }

      it 'maps to animal' do
        expect(mapping.observationType).to eq('animal')
      end
    end

    context 'with a common name tag' do
      let(:tag) { create(:tag, type_of_tag: 'common_name', text: 'Common test', is_taxonomic: true) }

      it 'maps to animal' do
        expect(mapping.observationType).to eq('animal')
      end
    end

    context 'with an unknown general tag' do
      let(:tag) { create(:tag, type_of_tag: 'general', text: 'unknown') }

      it 'maps to unknown' do
        expect(mapping.observationType).to eq('unknown')
      end
    end

    context 'with a human general tag' do
      let(:tag) { create(:tag, type_of_tag: 'general', text: 'Human Voice') }

      it 'maps to human' do
        expect(mapping.observationType).to eq('human')
      end
    end

    context 'with a vehicle general tag' do
      let(:tag) { create(:tag, type_of_tag: 'general', text: 'chainsaw') }

      it 'maps to vehicle' do
        expect(mapping.observationType).to eq('vehicle')
      end
    end

    context 'with an unmatched general tag' do
      let(:tag) { create(:tag, type_of_tag: 'general', text: 'weather') }

      it 'maps to unclassified' do
        expect(mapping.observationType).to eq('unclassified')
      end
    end
  end
end
