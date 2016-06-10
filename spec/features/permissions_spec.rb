require 'rails_helper'

describe 'Permissions', type: :feature do
  create_entire_hierarchy

  context 'as logged in user' do
    context 'are allowed with owner permission' do
      before(:each) { login_as owner_user, scope: :user }
      it 'lists project permissions' do
        visit project_permissions_path(project)
        expect(page).to have_content('Permissions')
      end

      def check_row(user, level)
        overall_selector = "tr[data-user-id='#{user.id}'] .overall-permission"
        overall = find(overall_selector)

        level = nil unless [:owner, :writer, :reader].include?(level)

        if !level.nil?
          expect(overall).not_to have_content('None')
        else
          expect(overall).to have_content('None')
        end

        if level != :reader
          expect(overall).not_to have_content('Reader')
        else
          expect(overall).to have_content('Reader')
        end

        if level != :writer
          expect(overall).not_to have_content('Writer')
        else
          expect(overall).to have_content('Writer')
        end

        if level != :owner
          expect(overall).not_to have_content('Owner')
        else
          expect(overall).to have_content('Owner')
        end
      end

      def check_project_row(permission_type, level)

        case permission_type
          when :anonymous
            id = 'project_wide_anonymous_permissions_level_'
          when :logged_in
            id = 'project_wide_logged_in_permissions_level_'
          else
            id = nil
        end

        expect(page).to have_selector("button##{id}none")
        expect(page).to have_selector("button##{id}reader")

        expect(page).to have_css("button##{id}none[disabled]") if level.nil?
        expect(page).to have_css("button##{id}reader[disabled]") if level == :reader


        if permission_type == :logged_in
          expect(page).to have_selector("button##{id}writer")
          expect(page).to have_css("button##{id}writer[disabled]") if level == :writer

        else
          expect(page).to have_no_selector("button##{id}writer")
        end
      end

      def change_permission(user, new_level)
        row = find(find_user_row = "tr[data-user-id='#{user.id}']")

        expect(current_path).to eq(project_permissions_path(project))

        case new_level
          when :owner
            row.click_button('Owner')
          when :writer
            row.click_button('Writer')
          when :reader
            row.click_button('Reader')
          else
            row.click_button('None')
        end

        expect(current_path).to eq(project_permissions_path(project))
        expect(page).to have_content('Permissions successfully updated.')

        check_row(user, new_level)
      end

      def change_project_permission(permission_type, new_level)
        expect(current_path).to eq(project_permissions_path(project))

        level = new_level.nil? ? 'none' : new_level.to_s
        if permission_type == :anonymous
          click_button('project_wide_anonymous_permissions_level_' + level)
        elsif permission_type == :logged_in
          click_button('project_wide_logged_in_permissions_level_' + level)
        end

        expect(current_path).to eq(project_permissions_path(project))
        expect(page).to have_content('Permissions successfully updated.')

        check_project_row(permission_type, new_level)
      end

      it 'has expected permissions' do
        visit project_permissions_path(project)
        #save_and_open_page

        # project-wide
        check_project_row(:anonymous, nil)
        check_project_row(:logged_in, nil)

        # users
        expect(page).to have_no_content('Admin')
        expect(page).to have_no_content('Harvester')

        check_row(owner_user, :owner)
        check_row(writer_user, :writer)
        check_row(reader_user, :reader)
        check_row(no_access_user, nil)
      end

      it 'updates project permissions for a user' do
        visit project_permissions_path(project)

        # set other user to writer
        change_permission(no_access_user, :writer)

        # then set other user back to no access
        change_permission(no_access_user, nil)
      end

      it 'updates project-wide permissions' do
        visit project_permissions_path(project)

        # set anon access to reader
        change_project_permission(:anonymous, :reader)

        # then set anon access back to no access
        change_project_permission(:anonymous, nil)

        # then set logged in access to writer
        change_project_permission(:logged_in, :writer)
      end
    end

    context 'are denied with writer permission' do
      before(:each) { login_as writer_user, scope: :user }
      it 'denies access to list project permissions' do
        visit project_permissions_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end
    end

    context 'are denied with reader permission' do
      before(:each) { login_as reader_user, scope: :user }
      it 'denies access to list project permissions' do
        visit project_permissions_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end
    end

  end
  context 'as guest user are denied' do
    it 'denies access to list project permissions' do
      visit project_permissions_path(project)
      expect(page).to have_content(I18n.t('devise.failure.unauthenticated'))
    end
  end
end
