module GlobalMenuHelper

  # make our custom url generation methods available to views
  include Api::CustomUrlHelpers

  EDIT_PATH = 'edit'
  NEW_PATH = 'new'

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
      next menu_item unless menu_item[:href].respond_to?(:call)

      # clone hash so we don't overwrite values
      new_item = menu_item.dup
      new_item[:href] = instance_exec(current_user, &menu_item[:href])
      next new_item
    }

    items
  end

  def insert_new_or_edit(item)
    if current_page?(item[:href], action: :new)
      return [item, {
          href: request.original_fullpath,
          title: t('helpers.titles.new'),
          icon: 'plus'
      }]
    end

    if current_page?(item[:href], action: :edit)
      return [item, {
          href: href,
          title: t('helpers.titles.edit'),
          icon: 'pencil'
      }]
    end

    item
  end

  # title and tooltip are translate keys
  # :controller is used to make new and edit links work automatically
  NAV_MENU = [
      {
          title: I18n.t('baw.shared.links.home.title'),
          href: Api::UrlHelpers.root_path,
          tooltip: I18n.t('baw.shared.links.home.description'),
          icon: 'home',
      },
      {
          title: I18n.t('baw.shared.links.log_in.title'),
          href: -> _ { Api::UrlHelpers.new_user_session_path },
          tooltip: I18n.t('baw.shared.links.log_in.description'),
          icon: 'sign-in',
          predicate: -> user { user.blank? },
      },
      {
          title: I18n.t('baw.shared.links.profile.title'),
          href: -> _ { Api::UrlHelpers.my_account_path },
          tooltip: I18n.t('baw.shared.links.profile.title'),
          icon: 'user',
          predicate: -> user { !user.blank? },
      },
      {
          title: I18n.t('baw.shared.links.register.title'),
          href: Api::UrlHelpers.new_user_registration_path,
          tooltip: I18n.t('baw.shared.links.register.description'),
          icon: 'user-plus',
          predicate: -> user { user.blank? },
      },
      {
          title: I18n.t('baw.shared.links.annotations.title'),
          href: -> user { Api::UrlHelpers.audio_events_user_account_path(user) },
          tooltip: I18n.t('baw.shared.links.annotations.description'),
          icon: 'baw-annotation',
          predicate: -> user { !user.blank? },
      },
      {
          title: I18n.t('baw.shared.links.projects.title'),
          href: Api::UrlHelpers.projects_path,
          tooltip: I18n.t('baw.shared.links.projects.description'),
          icon: 'globe',
      },
      {
          title: I18n.t('baw.shared.links.project.title'),
          href: -> _ { Api::UrlHelpers.project_path(@project) },
          tooltip: I18n.t('baw.shared.links.project.description'),
          icon: 'folder-open',
          indentation: 1,
          predicate: -> _ { @project },
          controller: ProjectsController
      },
      {
          title: I18n.t('baw.shared.links.site.title'),
          href: -> _ { Api::UrlHelpers.project_site_path(@project, @site) },
          tooltip: I18n.t('baw.shared.links.site.description'),
          icon: 'map-marker',
          indentation: 2,
          predicate: -> _ { @site },
          controller: SitesController
      },
      {
          title: I18n.t('baw.shared.links.harvest.short_title'),
          href: -> _ { Api::UrlHelpers.upload_instructions_project_site_path(@project, @site) },
          tooltip: I18n.t('baw.shared.links.harvest.description'),
          icon: '',
          indentation: 3,
          predicate: -> _ { request.path.ends_with?('upload_instructions') }
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
          icon: 'table',
      },
      {
          title: I18n.t('baw.shared.links.upload_audio.title'),
          href: Api::UrlHelpers.data_upload_path,
          tooltip: I18n.t('baw.shared.links.upload_audio.description'),
          icon: 'envelope',
      },
      {
          title: I18n.t('baw.shared.links.report_problem.title'),
          href: Api::UrlHelpers.bug_report_path,
          tooltip: I18n.t('baw.shared.links.report_problem.description'),
          icon: 'bug',
      },
      {
          title: I18n.t('baw.shared.links.website_status.title'),
          href: Api::UrlHelpers.website_status_path,
          tooltip: I18n.t('baw.shared.links.website_status.description'),
          icon: 'line-chart',
      }
  ].freeze
end