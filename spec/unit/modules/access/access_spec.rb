describe Access do
  # https://github.com/QutEcoacoustics/baw-server/issues/333
  context 'a user has multiple assigned permissions' do
    create_entire_hierarchy

    def test_level_name
      levels = Access::Core.user_levels(owner_user, project)
      highest_level = Access::Core.highest(levels)
      Access::Core.get_level_name(highest_level)
    end

    example 'a user is an owner and also has logged in read permissions' do
      # give the project logged in read access
      Permission
        .new(creator: owner_user, project: project, user: nil, allow_logged_in: true, allow_anonymous: false, level: 'reader')
        .save!

      expect(test_level_name).to eq('Owner')
    end

    example 'a user is an owner and also has logged in write permissions' do
      # give the project logged in write access
      Permission
        .new(creator: owner_user, project: project, user: nil, allow_logged_in: true, allow_anonymous: false, level: 'writer')
        .save!

      expect(test_level_name).to eq('Owner')
    end
  end
end
