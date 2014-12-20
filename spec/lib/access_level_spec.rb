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

  context 'equal ot greater to the correct levels' do
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

  context 'truth table' do

    # :owner level for sign_in_level and anonymous_level
    # is not permitted - this is tested elsewhere

    [:none, :reader, :writer, :owner].each do |requested_level|
      %w(anon_user different_user same_user admin_user).each do |requested_user|
        %w(same_project different_project).each do |requested_project|
          [:none, :reader, :writer, :owner].each do |actual_level|
            [true, false].each do |actual_logged_in|
              [true, false].each do |actual_anonymous|
                %w(anon_user user admin_user).each do |permission_user|
                  it "Requested #{requested_user}:#{requested_level}:#{requested_project} | Actual #{permission_user}:#{actual_level}:Logged In #{actual_logged_in}:Anonymous #{actual_anonymous}" do

                    # create permission using actual_level, actual_logged_in, actual_anonymous, permission_user
                    actual_project = FactoryGirl.create(:project)

                    if permission_user == 'anon_user'
                      actual_user = nil
                    elsif permission_user == 'user'
                      actual_user = FactoryGirl.create(:user)
                    elsif permission_user == 'admin_user'
                      actual_user = FactoryGirl.create(:admin)
                    else
                      actual_user = nil
                    end

                    permission = FactoryGirl.build(:permission, user: actual_user, project: actual_project, level: actual_level, logged_in_user: actual_logged_in, anonymous_user: actual_anonymous)

                    true_count = [actual_logged_in, actual_anonymous, !actual_user.nil?].count(true)
                    if true_count != 1
                      expect {
                        permission.save!
                      }.to raise_error(ActiveRecord::RecordNotUnique, /A permission can store only one of/)
                    elsif actual_level == :none
                      expect {
                        permission.save!
                      }.to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Level is not included in the list, Level none is not a valid level/)
                    else
                      permission.save!
                    end

                    # check permission using requested level, requested user, requested_project
                    if requested_user == 'anon_user'
                      expected_user = nil
                    elsif permission_user == 'same_user'
                      expected_user = actual_user
                    elsif permission_user == 'different_user'
                      expected_user = FactoryGirl.create(:user)
                    elsif permission_user == 'admin_user'
                      expected_user = FactoryGirl.create(:admin)
                    else
                      expected_user = nil
                    end

                    if requested_project == 'same_project'
                      expected_project = actual_project
                    elsif requested_project == 'different_project'
                      expected_project = FactoryGirl.create(:project)
                    else
                      expected_project = nil
                    end

                    result = AccessLevel.access?(expected_user, expected_project, requested_level)

                    # assertions

                  end
                end
              end
            end
          end
        end
      end
    end
  end


end