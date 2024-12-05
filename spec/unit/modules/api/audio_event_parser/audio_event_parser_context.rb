# frozen_string_literal: true

RSpec.shared_context 'audio_event_parser' do
  create_entire_hierarchy

  let(:import) { audio_event_import }
  let(:import_file) { audio_event_import_file }
  let(:another_recording) { create(:audio_recording, site:) }

  let(:notes) {
    {
      'created' => { 'message' => 'Created via audio event import', 'audio_event_import_id' => import.id }
    }
  }

  let!(:tag_crickets) {
    create(:tag, text: 'crickets', type_of_tag: :common_name, is_taxonomic: true)
  }
end
