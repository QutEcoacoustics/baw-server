require 'spec_helper'

describe AccessLevel do

  context 'decomposes to the correct levels' do
    it 'from blah' do
      expect {
        AccessLevel.equal_or_greater(:blah)
      }.to raise_error(ArgumentError, /Access level 'blah' is not in available levels '\[:owner, :writer, :reader, :none\]'\./)
    end

    it 'from none' do
      result = AccessLevel.equal_or_lower(:none)
      expect(result).to eq([:none])
    end

    it 'from reader' do
      result = AccessLevel.equal_or_lower(:reader)
      expect(result).to eq([:reader])
    end

    it 'from writer' do
      result = AccessLevel.equal_or_lower(:writer)
      expect(result).to eq([:reader, :writer])
    end

    it 'from owner' do
      result = AccessLevel.equal_or_lower(:owner)
      expect(result).to eq([:reader, :writer, :owner])
    end

  end

  context 'at least returns the correct levels' do
    it 'from blah' do
      expect {
        AccessLevel.equal_or_greater(:blah)
      }.to raise_error(ArgumentError, /Access level 'blah' is not in available levels '\[:owner, :writer, :reader, :none\]'\./)
    end

    it 'from none' do
      result = AccessLevel.equal_or_greater(:none)
      expect(result).to eq([:none])
    end

    it 'from reader' do
      result = AccessLevel.equal_or_greater(:reader)
      expect(result).to eq([:reader, :writer, :owner])
    end

    it 'from writer' do
      result = AccessLevel.equal_or_greater(:writer)
      expect(result).to eq([:writer, :owner])
    end

    it 'from owner' do
      result = AccessLevel.equal_or_greater(:owner)
      expect(result).to eq([:owner])
    end

  end

  context 'checks enforce valid levels' do
    context 'for owner' do
      it 'allows owner' do
        expect(AccessLevel.check(:owner, :owner)).to be_truthy
      end
      it 'allows writer' do
        expect(AccessLevel.check(:writer, :owner)).to be_truthy
      end
      it 'allows reader' do
        expect(AccessLevel.check(:reader, :owner)).to be_truthy
      end
      it 'disallows none' do
        expect(AccessLevel.check(:none, :owner)).to be_falsey
      end
    end

    context 'for writer' do
      it 'disallows owner' do
        expect(AccessLevel.check(:owner, :writer)).to be_falsey
      end
      it 'allows writer' do
        expect(AccessLevel.check(:writer, :writer)).to be_truthy
      end
      it 'allows reader' do
        expect(AccessLevel.check(:reader, :writer)).to be_truthy
      end
      it 'disallows none' do
        expect(AccessLevel.check(:none, :writer)).to be_falsey
      end
    end

    context 'for reader' do
      it 'disallows owner' do
        expect(AccessLevel.check(:owner, :reader)).to be_falsey
      end
      it 'disallows writer' do
        expect(AccessLevel.check(:writer, :reader)).to be_falsey
      end
      it 'allows reader' do
        expect(AccessLevel.check(:reader, :reader)).to be_truthy
      end
      it 'disallows none' do
        expect(AccessLevel.check(:none, :reader)).to be_falsey
      end
    end

    context 'for none' do
      it 'disallows owner' do
        expect(AccessLevel.check(:owner, :none)).to be_falsey
      end
      it 'disallows writer' do
        expect(AccessLevel.check(:writer, :none)).to be_falsey
      end
      it 'disallows reader' do
        expect(AccessLevel.check(:reader, :none)).to be_falsey
      end
      it 'allows none' do
        expect(AccessLevel.check(:none, :none)).to be_truthy
      end
    end

  end

  context 'when checking project permission for a user' do

    it 'fails getting permission when project does not exist in db for nil user' do
      result = AccessLevel.permission_level(nil, FactoryGirl.build(:project))
      expect(result).to eq(:none)
    end

    it 'fails checking permission when project does not exist in db for nil user' do
      result = AccessLevel.permission_level?(nil, FactoryGirl.build(:project), :none)
      expect(result).to be_truthy
    end

    it 'fails getting permission for user with no permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      result = AccessLevel.permission_level(user, project)
      expect(result).to eq(:none)
    end

    it 'succeeds checking permission for user with no permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      result = AccessLevel.permission_level?(user, project, :none)
      expect(result).to be_truthy
    end

    it 'succeeds getting permission for user with read permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'reader')
      result = AccessLevel.permission_level(user, project)
      expect(result).to eq(:reader)
    end

    it 'succeeds checking permission for user with read permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'reader')
      result = AccessLevel.permission_level?(user, project, :reader)
      expect(result).to be_truthy
    end

    it 'fails checking writer permission for user with read permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'reader')
      result = AccessLevel.permission_level?(user, project, :writer)
      expect(result).to be_falsey
    end

    it 'succeeds getting permission for user with write permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'writer')
      result = AccessLevel.permission_level(user, project)
      expect(result).to eq(:writer)
    end

    it 'succeeds checking permission for user with write permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'writer')
      result = AccessLevel.permission_level?(user, project, :writer)
      expect(result).to be_truthy
    end

    it 'succeeds checking reader permission for user with write permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'writer')
      result = AccessLevel.permission_level?(user, project, :reader)
      expect(result).to be_truthy
    end

    it 'succeeds checking reader permission for user with owner permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: 'owner')
      result = AccessLevel.permission_level?(user, project, :reader)
      expect(result).to be_truthy
    end

  end

  context 'when checking access to a project' do
    it 'fails getting permission when project does not exist in db for nil user' do
      result = AccessLevel.access?(nil, FactoryGirl.build(:project), :reader)
      expect(result).to be_falsey
    end

    it 'fails checking permission when project does not exist in db for nil user' do
      result = AccessLevel.access?(nil, FactoryGirl.build(:project), :none)
      expect(result).to be_truthy
    end

    it 'succeeds checking reader permission for user with owner permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: :owner)
      result = AccessLevel.access?(user, project, :reader)
      expect(result).to be_truthy
    end

    it 'succeeds checking owner permission for admin user with no permission' do
      user = FactoryGirl.create(:admin)
      project = FactoryGirl.create(:project)
      result = AccessLevel.access?(user, project, :owner)
      expect(result).to be_truthy
    end

    it 'succeeds checking owner permission for creator user with no permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, creator: user)
      result = AccessLevel.access?(user, project, :owner)
      expect(result).to be_truthy
    end

    it 'fails checking owner permission for user with writer permission' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project)
      permission = FactoryGirl.create(:permission, user: user, project: project, level: :writer)
      result = AccessLevel.access?(user, project, :owner)
      expect(result).to be_falsey
    end

    it 'fails checking writer permission for project with sign_in_level of reader' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, sign_in_level: :reader)
      result = AccessLevel.access?(user, project, :writer)
      expect(result).to be_falsey
    end

    it 'succeeds checking writer permission for project with sign_in_level of writer' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, sign_in_level: :writer)
      result = AccessLevel.access?(user, project, :writer)
      expect(result).to be_truthy
    end

    it 'fails checking writer permission for project with anonymous_level of reader' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, anonymous_level: :reader)
      result = AccessLevel.access?(user, project, :writer)
      expect(result).to be_falsey
    end

    it 'succeeds checking writer permission for project with anonymous_level of writer' do
      project = FactoryGirl.create(:project, anonymous_level: :writer)
      result = AccessLevel.access?(nil, project, :writer)
      expect(result).to be_truthy
    end

    it 'fails checking writer permission for project with anonymous_level of none' do
      project = FactoryGirl.create(:project, anonymous_level: :none)
      result = AccessLevel.access?(nil, project, :writer)
      expect(result).to be_falsey
    end

    it 'succeeds checking none permission for project with anonymous_level of none' do
      project = FactoryGirl.create(:project, anonymous_level: :none)
      result = AccessLevel.access?(nil, project, :none)
      expect(result).to be_truthy
    end

    it 'fails checking none permission for project with anonymous_level of writer' do
      project = FactoryGirl.create(:project, anonymous_level: :writer)
      result = AccessLevel.access?(nil, project, :none)
      expect(result).to be_falsey
    end

    it 'succeeds checking none permission for project with anonymous_level of writer' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, anonymous_level: :writer)
      result = AccessLevel.access?(user, project, :none)
      expect(result).to be_truthy
    end

    it 'fails checking none permission for project with sign_in_level of writer' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, sign_in_level: :writer)
      result = AccessLevel.access?(user, project, :none)
      expect(result).to be_falsey
    end

    it 'succeeds checking none permission for project with anonymous_level of writer' do
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, creator: user)
      result = AccessLevel.access?(user, project, :none)
      expect(result).to be_falsey
    end

    context 'any' do
      it 'succeeds when access to one of three projects' do
        user = FactoryGirl.create(:user)
        project1 = FactoryGirl.create(:project)
        project2 = FactoryGirl.create(:project)
        project3 = FactoryGirl.create(:project, creator: user)
        projects = [project1, project2, project3]
        result = AccessLevel.access_any?(user, projects, :owner)
        expect(result).to be_truthy
      end

      it 'fails when access to none of three projects' do
        user = FactoryGirl.create(:user)
        project1 = FactoryGirl.create(:project)
        project2 = FactoryGirl.create(:project)
        project3 = FactoryGirl.create(:project)
        projects = [project1, project2, project3]
        result = AccessLevel.access_any?(user, projects, :owner)
        expect(result).to be_falsey
      end
    end

    context 'all' do
      it 'succeeds when access to three of three projects' do
        user = FactoryGirl.create(:user)
        project1 = FactoryGirl.create(:project, creator: user)
        project2 = FactoryGirl.create(:project, creator: user)
        project3 = FactoryGirl.create(:project, creator: user)
        projects = [project1, project2, project3]
        result = AccessLevel.access_all?(user, projects, :owner)
        expect(result).to be_truthy
      end

      it 'fails when access to two of three projects' do
        user = FactoryGirl.create(:user)
        project1 = FactoryGirl.create(:project)
        project2 = FactoryGirl.create(:project, creator: user)
        project3 = FactoryGirl.create(:project, creator: user)
        projects = [project1, project2, project3]
        result = AccessLevel.access_all?(user, projects, :owner)
        expect(result).to be_falsey
      end
    end

  end

  context 'check user project access level' do
    it 'fails when nil' do
      expect {
        AccessLevel.projects(nil, nil)
      }.to raise_error(ArgumentError, /Access level must not be blank\./)
    end
  end

  context 'error occurs when' do
    it 'decomposes an invalid value' do
      expect {
        AccessLevel.equal_or_lower(:blah_blah)
      }.to raise_error(ArgumentError, /Access level 'blah_blah' is not in available levels/)
    end

    it 'validates something that is not an array' do
      expect {
        AccessLevel.validate_array(:blah_blah)
      }.to raise_error(ArgumentError, /Value must be a collection of items, got Symbol/)
    end

    it 'checks permission for nil project' do
      expect {
        AccessLevel.permission_level(nil, nil)
      }.to raise_error(ArgumentError, 'Project must be provided.')
    end

    it 'checks access for nil project' do
      expect {
        AccessLevel.access?(nil, nil, :none)
      }.to raise_error(ArgumentError, 'Project must be provided.')
    end

  end

  context 'truth table' do

    # :owner level for sign_in_level and anonymous_level
    # is not permitted - this is tested elsewhere

    [:none, :reader, :writer].each do |sign_in_level|
      [:none, :reader, :writer].each do |anonymous_level|
        [:none, :reader, :writer, :owner].each do |permission_level|
          %w(anon user admin).each do |user_type|
            [:none, :reader, :writer, :owner].each do |requested_level|
              it "Requested #{requested_level}, User #{user_type}, Permission #{permission_level}, Signed In #{sign_in_level}, Anonymous #{anonymous_level}" do

                user = nil # user_type == 'anon'
                if user_type == 'user'
                  user = FactoryGirl.create(:user)
                elsif user_type == 'admin'
                  user = FactoryGirl.create(:admin)
                end

                project = FactoryGirl.create(:project, sign_in_level: sign_in_level, anonymous_level: anonymous_level)

                if user_type != 'anon' && permission_level != :none && !user.blank?
                  FactoryGirl.create(:permission, user: user, project: project, level: permission_level)
                end

                result = AccessLevel.access?(user, project, requested_level)

                if user_type == 'admin'
                  expect(result).to be_truthy
                elsif user_type == 'user'
                  highest = AccessLevel.highest([sign_in_level, permission_level])
                  highest_decomposed = AccessLevel.equal_or_lower(highest)
                  expected = highest_decomposed.include?(requested_level)
                  expect(expected).to eq(result), "highest: #{highest_decomposed}, requested: #{requested_level}, expected: #{expected}, result: #{result}"
                elsif user_type == 'anon'
                  anon_decomposed = AccessLevel.equal_or_lower(anonymous_level)
                  expected = anon_decomposed.include?(requested_level)
                  expect(expected).to eq(result), "anon: #{anon_decomposed}, requested: #{requested_level}, expected: #{expected}, result: #{result}"
                end

              end
            end
          end
        end
      end
    end
  end

  it 'selects the highest of all levels' do
    result = AccessLevel.highest([:writer, :owner, :reader, :none])
    expect(result).to eq(:owner)
  end

  it 'selects the highest of two levels' do
    result = AccessLevel.highest([:writer, :none])
    expect(result).to eq(:writer)
  end

  it 'selects the lowest of all levels' do
    result = AccessLevel.lowest([:writer, :owner, :reader, :none])
    expect(result).to eq(:none)
  end

  it 'selects the lowest of two levels' do
    result = AccessLevel.lowest([:owner, :reader])
    expect(result).to eq(:reader)
  end

  it 'displays the correct value for writer' do
    expect(AccessLevel.obj_to_display(:writer)).to eq('Writer')
  end

  it 'displays the correct value for none' do
    expect(AccessLevel.obj_to_display(:none)).to eq('None')
  end

  it 'describes the correct value for writer' do
    expect(AccessLevel.obj_to_description(:writer)).to eq('has write permission to the project')
  end

  it 'describes the correct value for none' do
    expect(AccessLevel.obj_to_description(:none)).to eq('has no permissions to the project')
  end


end