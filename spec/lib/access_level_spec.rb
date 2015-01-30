require 'spec_helper'

describe AccessLevel do

  it 'ensures permission strings are correct' do
    expect(AccessLevel.permission_strings).to eq(%w(reader writer owner))
  end

  it 'ensures permission symbols are correct' do
    expect(AccessLevel.permission_symbols).to eq([:reader, :writer, :owner])
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

  context 'user type check' do
    %w(user unconfirmed nil admin harvester).each do |user_type|
      it "checks whether #{user_type} is validated correctly" do
        case user_type
          when 'user'
            user = FactoryGirl.create(:user)
          when 'unconfirmed'
            user = FactoryGirl.create(:unconfirmed_user)
          when 'admin'
            user = FactoryGirl.create(:admin)
          when 'harvester'
            user = FactoryGirl.create(:harvester)
          when 'nil'
          else
            user = nil
        end

        is_standard_user = AccessLevel.is_standard_user?(user)
        is_harvester = AccessLevel.is_harvester?(user)
        is_admin = AccessLevel.is_admin?(user)
        is_guest = AccessLevel.is_guest?(user)

        expect(is_standard_user).to eq(user_type == 'user')
        expect(is_harvester).to eq(user_type == 'harvester')
        expect(is_admin).to eq(user_type == 'admin')
        expect(is_guest).to eq(user_type == 'nil' || user_type == 'unconfirmed')
      end
    end
  end

  context 'equal or lower to the correct levels' do
    it 'from blah' do
      expect {
        AccessLevel.equal_or_lower(:blah)
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

  context 'equal or greater to the correct levels' do
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

  context 'is allowed, highest, and lowest validates correctly' do

    levels_available = AccessLevel.permission_all
    levels_count = levels_available.size


    (0..(levels_count)).to_a.each do |requested_count|
      levels_available.combination(requested_count).to_a.each do |requested_combination|

        it "correctly gets highest in #{requested_combination.join(', ')}" do
          if requested_combination.include?(:owner)
            actual = :owner
          elsif requested_combination.include?(:writer)
            actual = :writer
          elsif requested_combination.include?(:reader)
            actual = :reader
          else
            actual = :none
          end

          if requested_combination.blank?
            expect {
              AccessLevel.highest(requested_combination)
            }.to raise_error(ArgumentError, 'Access level array must not be blank.')
          elsif requested_combination.include?(:none) && requested_combination.size > 1
            expect {
              AccessLevel.highest(requested_combination)
            }.to raise_error(ArgumentError, /Level array cannot contain none with other levels/)
          else
            expect(AccessLevel.highest(requested_combination)).to eq(actual)
          end
        end

        it "correctly gets lowest in #{requested_combination.join(', ')}" do
          if requested_combination.include?(:none)
            actual = :none
          elsif requested_combination.include?(:reader)
            actual = :reader
          elsif requested_combination.include?(:writer)
            actual = :writer
          else
            actual = :owner
          end

          if requested_combination.blank?
            expect {
              AccessLevel.lowest(requested_combination)
            }.to raise_error(ArgumentError, 'Access level array must not be blank.')
          elsif requested_combination.include?(:none) && requested_combination.size > 1
            expect {
              AccessLevel.lowest(requested_combination)
            }.to raise_error(ArgumentError, /Level array cannot contain none with other levels/)
          else
            expect(AccessLevel.lowest(requested_combination)).to eq(actual)
          end
        end

        # 16 x 16 = 256 tests
        (0..(levels_count)).to_a.each do |actual_count|
          levels_available.combination(actual_count).to_a.each do |actual_combination|
            it "For '#{requested_combination.join(', ')}' requested items when '#{actual_combination.join(', ')}' actual items." do

              normalised_requested_combination = requested_combination.flatten.compact
              if normalised_requested_combination.empty?
                requested = nil
              elsif normalised_requested_combination.size == 1
                requested = normalised_requested_combination[0]
              else
                requested = normalised_requested_combination
              end

              normalised_actual_combination = actual_combination.flatten.compact
              if normalised_actual_combination.empty?
                actual = nil
              elsif normalised_actual_combination.size == 1
                actual = normalised_actual_combination[0]
              else
                actual = normalised_actual_combination
              end

              if requested.blank?
                expect {
                  AccessLevel.is_allowed?(requested, actual)
                }.to raise_error(ArgumentError, 'Access level must not be blank.')
              elsif requested.is_a?(Array) && requested.include?(:none) && requested.size > 1
                expect {
                  AccessLevel.is_allowed?(requested, actual)
                }.to raise_error(ArgumentError, /Level array cannot contain none with other levels/)
              elsif actual.blank?
                expect {
                  AccessLevel.is_allowed?(requested, actual)
                }.to raise_error(ArgumentError, 'Access level must not be blank.')
              elsif actual.is_a?(Array) && actual.include?(:none) && actual.size > 1
                expect {
                  AccessLevel.is_allowed?(requested, actual)
                }.to raise_error(ArgumentError, /Level array cannot contain none with other levels/)
              else
                result = AccessLevel.is_allowed?(requested, actual)

                # '&' is intersection of arrays
                # (a & b).empty? is true if nothing in common, false if any element in common

                if (normalised_requested_combination.include?(:none) && (normalised_actual_combination & [:none]).empty?) ||
                    (normalised_requested_combination.include?(:owner) && (normalised_actual_combination & [:owner]).empty?) ||
                    (normalised_requested_combination.include?(:writer) && (normalised_actual_combination & [:owner, :writer]).empty?) ||
                    (normalised_requested_combination.include?(:reader) && (normalised_actual_combination & [:owner, :writer, :reader]).empty?)
                  expect(result).to be_falsey
                else
                  expect(result).to be_truthy
                end


              end

            end
          end
        end
      end
    end

  end

  it 'requires a project for access? method' do
    expect {
      AccessLevel.access?(nil, nil, :none)
    }.to raise_error(ArgumentError, /Project was not valid, got /)
  end

  it 'tests all combinations of access?(user, project, level)' do

    # create all possible combinations of permissions
    admin = FactoryGirl.create(:admin)
    combinations = []

    [:none, :reader, :writer, :owner].each do |level|
      [true, false].each do |logged_in|
        [true, false].each do |anonymous|
          %w(guest user).each do |user_type|


            if user_type == 'user'
              user = FactoryGirl.create(:user)
            else # user_type == 'anon_user'
              user = nil
            end

            project = FactoryGirl.create(:project)
            true_count = [logged_in, anonymous, !user.nil?].count(true)

            #msg = "#{level}: logged_in #{logged_in}; anonymous #{anonymous}; user #{!user.nil?}"

            if level == :none
              expect {
                permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
              }.to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Level is not included in the list/)
            elsif true_count > 1
              expect {
                permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
              }.to raise_error(ActiveRecord::RecordInvalid, /can't be true when anonymous user is true|can't be true when logged in user is true|can't be true when user id is set/)
            elsif true_count < 1
              expect {
                permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
              }.to raise_error(ActiveRecord::RecordInvalid, /User must be set if anonymous user and logged in user are false/)
            elsif logged_in && ![:reader, :writer].include?(level)
              expect {
                permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
              }.to raise_error(ActiveRecord::RecordInvalid, /Level for logged in user must be one of reader\, writer/)
            elsif anonymous && :reader != level
              expect {
                permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
              }.to raise_error(ActiveRecord::RecordInvalid, /for anonymous user must be reader/)
            else
              permission = FactoryGirl.create(:permission, user: user, project: project, level: level, logged_in_user: logged_in, anonymous_user: anonymous)
            end

            user_hash = {
                project: project,
                user: user,
                permission: permission,
                level: level,
                logged_in: logged_in,
                anonymous: anonymous
            }

            combinations.push(user_hash)

            admin_hash = {
                project: project.reload,
                user: admin,
                permission: permission,
                level: level,
                logged_in: logged_in,
                anonymous: anonymous
            }

            combinations.push(admin_hash)

          end
        end
      end
    end

    combinations.each do |combination|
      msg = "user #{combination[:user].nil? ? nil : combination[:user].role_symbols }, project #{combination[:project].id}, #{combination[:level]}, logged in #{combination[:logged_in]}, anonymous #{combination[:anonymous]}"
      Rails.logger.info "New Combination. #{msg}"

      access_result = AccessLevel.access?(combination[:user], combination[:project], combination[:level])
      get_permissions = Permission.where(project_id: combination[:project].id, user_id: combination[:user].nil? ? nil : combination[:user].id)
      Rails.logger.info "Access test '#{access_result}': #{get_permissions.to_yaml}"

      projects_result = AccessLevel.projects(combination[:user], combination[:level]).map { |p| p.id }.to_a.sort

      Rails.logger.info "Projects test '#{projects_result.join(', ')}'"


#       msg = "project #{combination[:project].id}, user #{combination[:user].nil? ? nil : combination[:user].id},
# permission #{combination[:permission].nil? ? nil : combination[:permission].id}, level #{combination[:level]},
# logged in #{combination[:logged_in]}, anonymous #{combination[:anonymous]}"
#
#       if combination[:level] != :none && [combination[:anonymous], combination[:logged_in], !combination[:user].nil?].count(true) > 1
#         expect(result).to be_falsey, msg
#       else
#         expect(result).to be_truthy, msg
#       end


    end
  end

end


