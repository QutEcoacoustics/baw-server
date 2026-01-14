describe Access do
  context 'effective_permissions' do
    create_audio_recordings_hierarchy
    create_anon_hierarchy

    let!(:another_project) { create(:project) }
    let(:owner_level) { Access::Permission::LEVEL_TO_INTEGER_MAP[Access::Permission::OWNER] }
    let(:writer_level) { Access::Permission::LEVEL_TO_INTEGER_MAP[Access::Permission::WRITER] }
    let(:reader_level) { Access::Permission::LEVEL_TO_INTEGER_MAP[Access::Permission::READER] }

    before do
      create(:permission,
        project: project_anon,
        creator: owner_user,
        user: nil,
        level: 'writer',
        allow_logged_in: true)
    end

    def execute(user, project_ids: nil)
      Access::EffectivePermission
        .add_effective_permissions_cte(Project.all, user, project_ids: project_ids)
        .order('projects.id')
        .pluck('projects.id', 'effective_level')
    end

    context 'without project scoping' do
      example 'admin has effective permission level determined correctly' do
        expect(execute(admin_user)).to match([
          [project.id, owner_level],
          [project_anon.id, owner_level],
          [another_project.id, owner_level]
        ])
      end

      example 'owner has effective permission level determined correctly' do
        expect(execute(owner_user)).to match([
          [project.id, owner_level],
          [project_anon.id, owner_level],
          [another_project.id, nil]
        ])
      end

      example 'writer has effective permission level determined correctly' do
        expect(execute(writer_user)).to match([
          [project.id, writer_level],
          [project_anon.id, writer_level],
          [another_project.id, nil]
        ])
      end

      example 'reader has effective permission level determined correctly' do
        expect(execute(reader_user)).to match([
          [project.id, reader_level],
          # this one is higher than user's level due to logged in writer access
          [project_anon.id, writer_level],
          [another_project.id, nil]
        ])
      end

      example 'anonymous has effective permission level determined correctly' do
        expect(execute(nil)).to match([
          [project.id, nil],
          [project_anon.id, reader_level],
          [another_project.id, nil]
        ])
      end
    end

    context 'with project scoping' do
      example 'admin has effective permission level determined correctly' do
        expect(execute(admin_user, project_ids: [project_anon.id])).to match([
          [project.id, nil],
          [project_anon.id, owner_level],
          [another_project.id, nil]
        ])
      end

      example 'owner has effective permission level determined correctly' do
        expect(execute(owner_user, project_ids: [project_anon.id])).to match([
          [project.id, nil],
          [project_anon.id, owner_level],
          [another_project.id, nil]
        ])
      end

      example 'writer has effective permission level determined correctly' do
        expect(execute(writer_user, project_ids: [project_anon.id])).to match([
          [project.id, nil],
          [project_anon.id, writer_level],
          [another_project.id, nil]
        ])
      end

      example 'reader has effective permission level determined correctly' do
        expect(execute(reader_user, project_ids: [project_anon.id])).to match([
          [project.id, nil],
          [project_anon.id, writer_level],
          [another_project.id, nil]
        ])
      end

      example 'anonymous has effective permission level determined correctly' do
        expect(execute(nil, project_ids: [project_anon.id])).to match([
          [project.id, nil],
          [project_anon.id, reader_level],
          [another_project.id, nil]
        ])
      end
    end
  end
end
