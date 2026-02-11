describe Access::ByPermissionTable do
  create_entire_hierarchy
  create_anon_hierarchy

  let!(:another_project) { create(:project) }

  before do
    create(:permission,
      project: project_anon,
      creator: owner_user,
      user: nil,
      level: 'writer',
      allow_logged_in: true)
  end

  context 'with projects it works as expected' do
    def common(user)
      Access::ByPermissionTable
        .projects(user, level: Access::Permission::READER)
        .order(:id)
        .pluck(:id)
    end

    example 'for admin' do
      expect(common(admin_user)).to eq([project.id, project_anon.id, another_project.id])
    end

    example 'for owner' do
      expect(common(owner_user)).to eq([project.id, project_anon.id])
    end

    example 'for writer' do
      expect(common(writer_user)).to eq([project.id, project_anon.id])
    end

    example 'for reader' do
      expect(common(reader_user)).to eq([project.id, project_anon.id])
    end

    example 'for anonymous' do
      expect(common(nil)).to eq([project_anon.id])
    end
  end

  context 'with sites it works as expected' do
    def common(user)
      Access::ByPermissionTable
        .sites(user, level: Access::Permission::READER)
        .order(:id)
        .pluck(:id)
    end

    example 'for admin' do
      expect(common(admin_user)).to eq([site.id, site_anon.id])
    end

    example 'for owner' do
      expect(common(owner_user)).to eq([site.id, site_anon.id])
    end

    example 'for writer' do
      expect(common(writer_user)).to eq([site.id, site_anon.id])
    end

    example 'for reader' do
      expect(common(reader_user)).to eq([site.id, site_anon.id])
    end

    example 'for anonymous' do
      expect(common(nil)).to eq([site_anon.id])
    end

    example 'with project_ids filter' do
      expect(
        Access::ByPermissionTable
          .sites(reader_user, level: Access::Permission::READER, project_ids: [project.id])
          .order(:id)
          .pluck(:id)
      ).to eq([site.id])
    end

    example 'with project_ids filter excluding all' do
      expect(
        Access::ByPermissionTable
          .sites(reader_user, level: Access::Permission::READER, project_ids: [another_project.id])
          .order(:id)
          .pluck(:id)
      ).to eq([])
    end
  end

  context 'with audio_events it works as expected' do
    # audio_event comes from create_entire_hierarchy (in the permissioned project)

    # An event in the anon project
    let!(:audio_event_anon) {
      create(:audio_event, audio_recording: audio_recording_anon, creator: owner_user)
    }

    # A reference audio event in the no-access project
    let!(:other_audio_recording) {
      other_site = create(:site, region: create(:region, project: another_project))
      create(:audio_recording, site: other_site)
    }

    let!(:audio_event_no_access) {
      create(:audio_event, audio_recording: other_audio_recording, creator: admin_user)
    }

    let!(:reference_audio_event) {
      create(:audio_event, audio_recording: other_audio_recording, creator: admin_user, is_reference: true)
    }

    def common(user)
      Access::ByPermissionTable
        .audio_events(user, level: Access::Permission::READER)
        .order(:id)
        .pluck(:id)
    end

    example 'for admin' do
      expect(common(admin_user)).to contain_exactly(
        audio_event.id, audio_event_anon.id, audio_event_no_access.id, reference_audio_event.id
      )
    end

    example 'for owner' do
      expect(common(owner_user)).to contain_exactly(
        audio_event.id, audio_event_anon.id, reference_audio_event.id
      )
    end

    example 'for writer' do
      expect(common(writer_user)).to contain_exactly(
        audio_event.id, audio_event_anon.id, reference_audio_event.id
      )
    end

    example 'for reader' do
      expect(common(reader_user)).to contain_exactly(
        audio_event.id, audio_event_anon.id, reference_audio_event.id
      )
    end

    example 'for anonymous' do
      expect(common(nil)).to contain_exactly(audio_event_anon.id, reference_audio_event.id)
    end

    example 'with project_ids filter' do
      # the project parameter is a filter, so it removes reference events, even though
      # they would normally be included regardless of permissions
      expect(
        Access::ByPermissionTable
          .audio_events(reader_user, level: Access::Permission::READER, project_ids: [project.id])
          .order(:id)
          .pluck(:id)
      ).to contain_exactly(audio_event.id)
    end

    example 'with project_ids filter excluding all' do
      # the reader user cannot access audio_event_no_access because it is in another project,
      # but it can access reference_audio_event because reference events are always accessible
      expect(
        Access::ByPermissionTable
          .audio_events(reader_user, level: Access::Permission::READER, project_ids: [another_project.id])
          .order(:id)
          .pluck(:id)
      ).to contain_exactly(reference_audio_event.id)
    end
  end

  context 'with Access::ByPermission the behaviour is identical' do
    # audio_event_anon needed for audio_events equivalence test
    let!(:audio_event_anon) {
      create(:audio_event, audio_recording: audio_recording_anon, creator: owner_user)
    }

    ['reader_user', 'writer_user', 'owner_user', 'admin_user', nil].each do |user_name|
      context "when user is #{user_name || 'anonymous'}" do
        example 'for projects' do
          user = user_name.nil? ? nil : send(user_name)

          by_permission_result = Access::ByPermission
            .projects(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          by_permission_table_result = Access::ByPermissionTable
            .projects(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          expect(by_permission_table_result).to eq(by_permission_result)
        end

        example 'for sites' do
          user = user_name.nil? ? nil : send(user_name)

          by_permission_result = Access::ByPermission
            .sites(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          by_permission_table_result = Access::ByPermissionTable
            .sites(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          expect(by_permission_table_result).to eq(by_permission_result)
        end

        example 'for audio_events' do
          user = user_name.nil? ? nil : send(user_name)

          by_permission_result = Access::ByPermission
            .audio_events(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          by_permission_table_result = Access::ByPermissionTable
            .audio_events(user, levels: Access::Permission::READER_OR_ABOVE)
            .order(:id)
            .pluck(:id)

          expect(by_permission_table_result).to eq(by_permission_result)
        end
      end
    end
  end
end
