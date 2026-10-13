# frozen_string_literal: true

describe Access::ByPermission do
  create_audio_recordings_hierarchy

  context 'with audio_events_tags' do
    let(:tag) { create(:tag, creator: owner_user) }
    let(:audio_event) { create(:audio_event, audio_recording:, creator: owner_user) }
    let!(:tagging) { create(:tagging, audio_event:, tag:, creator: owner_user) }

    let(:second_project) { create(:project, creator: admin_user) }
    let(:second_site) { create(:site, region: nil, projects: [second_project], creator: owner_user) }
    let(:second_audio_recording) { create(:audio_recording, site: second_site, creator: owner_user) }
    let(:second_audio_event) {
      create(:audio_event, audio_recording: second_audio_recording, creator: owner_user)
    }
    let!(:second_tagging) { create(:tagging, audio_event: second_audio_event, tag:, creator: owner_user) }

    before do
      create(:read_permission, project: second_project, creator: second_project.creator, user: owner_user)
    end

    it 'returns taggings from all accessible projects without project_ids' do
      result = Access::ByPermission
        .audio_events_tags(owner_user, levels: Access::Permission::READER_OR_ABOVE)
        .pluck(:id)

      expect(result).to contain_exactly(tagging.id, second_tagging.id)
    end

    it 'returns only taggings from the specified project with project_ids' do
      result = Access::ByPermission
        .audio_events_tags(owner_user, levels: Access::Permission::READER_OR_ABOVE, project_ids: [project.id])
        .pluck(:id)

      expect(result).to contain_exactly(tagging.id)
    end
  end
end
