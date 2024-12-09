# frozen_string_literal: true

module GlobalMenuHelper
  # make our custom url generation methods available to views
  include Api::CustomUrlHelpers

  EDIT_PATH = 'edit'
  NEW_PATH = 'new'

  def extra_items
    @extra_items ||= {}
  end

  def set_current_menu_item(key, menu_item)
    extra_items[key] = menu_item
  end

  def menu_new_link(key, href, model_name = nil)
    set_current_menu_item(key, {
      href: href,
      title: "#{t('helpers.titles.new')} #{t("baw.shared.links.#{model_name}.title").downcase}",
      icon: 'plus'
    })
  end

  def menu_edit_link(key, href, model_name = nil)
    editing_what = model_name.blank? ? '' : " #{t("baw.shared.links.#{model_name}.title").downcase}"
    set_current_menu_item(key, {
      href: href,
      title: t('helpers.titles.editing') + editing_what,
      icon: 'pencil'
    })
  end

  def menu_default_link(title, icon = nil)
    set_current_menu_item(title.to_sym, {
      href: request.original_fullpath,
      title: t("baw.shared.links.#{title}.title"),
      tooltip: t("baw.shared.links.#{title}.description"),
      icon: icon
    })
  end

  def menu_definition
    current_user = controller.current_user

    items = NAV_MENU

    # filter items based on their predicate (if it exists)
    items = items.select { |menu_item|
      next true if menu_item.nil?
      next true unless menu_item.include?(:predicate)
      next true unless menu_item[:predicate].respond_to?(:call)

      next instance_exec(current_user, &menu_item[:predicate])
    }

    # finally transform any dynamic hrefs
    items = items.map { |menu_item|
      next menu_item if menu_item.nil?

      new_item = menu_item
      if menu_item[:href].respond_to?(:call)
        # clone hash so we don't overwrite values
        new_item = menu_item.dup
        new_item[:href] = instance_exec(current_user, &menu_item[:href])
      end

      # insert any other items
      if extra_items.key?(new_item[:id])
        extra = extra_items.delete(new_item[:id])
        extra[:indentation] = (new_item[:indentation] || 0) + 1
        next [new_item, extra]
      end

      next new_item
    }.flatten

    # lastly append any extra items
    items.concat(extra_items.values)
  end

  # title and tooltip are translate keys
  # :controller is used to make new and edit links work automatically
  NAV_MENU = [
    {
      title: I18n.t('baw.shared.links.home.title'),
      href: ->(_) { Api::UrlHelpers.root_path },
      tooltip: I18n.t('baw.shared.links.home.description'),
      icon: 'home'
    },
    {
      id: :login,
      title: I18n.t('baw.shared.links.log_in.title'),
      href: ->(_) { Api::UrlHelpers.new_user_session_path },
      tooltip: I18n.t('baw.shared.links.log_in.description'),
      icon: 'sign-in',
      predicate: ->(user) { user.blank? }
    },
    {
      id: :my_profile,
      title: I18n.t('baw.shared.links.profile.title'),
      href: ->(_) { Api::UrlHelpers.my_account_path },
      tooltip: I18n.t('baw.shared.links.profile.description'),
      icon: 'user',
      predicate: ->(user) { user.present? }
    },
    {
      title: I18n.t('baw.shared.links.register.title'),
      href: Api::UrlHelpers.new_user_registration_path,
      tooltip: I18n.t('baw.shared.links.register.description'),
      icon: 'user-plus',
      predicate: ->(user) { user.blank? }
    },
    {
      title: I18n.t('baw.shared.links.annotations.title'),
      href: ->(user) { Api::UrlHelpers.audio_events_user_account_path(user) },
      tooltip: I18n.t('baw.shared.links.annotations.description'),
      icon: 'baw-annotation',
      predicate: ->(user) { user.present? }
    },
    {
      id: :projects,
      title: I18n.t('baw.shared.links.projects.title'),
      href: Api::UrlHelpers.projects_path,
      tooltip: I18n.t('baw.shared.links.projects.description'),
      icon: 'globe'
    },
    {
      id: :project,
      title: I18n.t('baw.shared.links.project.title'),
      href: ->(_) { Api::UrlHelpers.project_path(@project) },
      tooltip: I18n.t('baw.shared.links.project.description'),
      icon: 'folder-open',
      indentation: 1,
      predicate: ->(_) { @project&.persisted? }
    },
    {
      title: I18n.t('baw.shared.links.site.title'),
      href: ->(_) { Api::UrlHelpers.project_site_path(@project, @site) },
      tooltip: I18n.t('baw.shared.links.site.description'),
      icon: 'map-marker',
      indentation: 2,
      predicate: ->(_) { @site&.persisted? },
      id: :site
    },
    {
      title: I18n.t('baw.shared.links.harvest.short_title'),
      href: ->(_) { Api::UrlHelpers.upload_instructions_project_site_path(@project, @site) },
      tooltip: I18n.t('baw.shared.links.harvest.description'),
      icon: '',
      indentation: 3,
      predicate: ->(_) { request.path.ends_with?('upload_instructions') }
    },
    {
      title: I18n.t('baw.shared.links.audio_analysis.title'),
      href: Api::UrlHelpers.make_audio_analysis_path,
      tooltip: I18n.t('baw.shared.links.audio_analysis.description'),
      icon: 'server',
      ribbon: 'beta'
    },
    {
      title: I18n.t('baw.shared.links.library.title'),
      href: Api::UrlHelpers.make_library_path,
      tooltip: I18n.t('baw.shared.links.library.description'),
      icon: 'book'
    },
    {
      title: I18n.t('baw.shared.links.data_request.title'),
      href: Api::UrlHelpers.data_request_path,
      tooltip: I18n.t('baw.shared.links.data_request.description'),
      icon: 'table'
    },
    {
      title: I18n.t('baw.shared.links.upload_audio.title'),
      href: Api::UrlHelpers.data_upload_path,
      tooltip: I18n.t('baw.shared.links.upload_audio.description'),
      icon: 'envelope'
    },
    {
      title: I18n.t('baw.shared.links.report_problem.title'),
      href: Api::UrlHelpers.bug_report_path,
      tooltip: I18n.t('baw.shared.links.report_problem.description'),
      icon: 'bug'
    },
    {
      title: I18n.t('baw.shared.links.website_status.title'),
      href: Api::UrlHelpers.website_status_path,
      tooltip: I18n.t('baw.shared.links.website_status.description'),
      icon: 'line-chart'
    }
  ].freeze
end
