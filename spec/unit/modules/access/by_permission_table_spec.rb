describe Access::ByPermissionTable do
  create_audio_recordings_hierarchy
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

  context 'with Access::ByPermission the behaviour is identical' do
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
      end
    end
  end
end
