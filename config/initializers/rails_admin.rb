RailsAdmin.config do |config|

  config.main_app_name = [Settings.organisation_names.parent_site_name, Settings.organisation_names.site_long_name, 'Admin']

  ### Popular gems integration

  # == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  # config.current_user_method(&:current_user)

  ## == Cancan ==
  #config.authorize_with :cancan

  # config.authorize_with do
  #   fail CanCan::AccessDenied.new(I18n.t('devise.failure.unauthorized')) unless current_user && Access::Check.is_admin?(current_user)
  # end

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end

  # settings for all models
  ActiveRecord::Base.descendants.each do |imodel|
    config.model "#{imodel.name}" do
      nested_form false

    end
  end
end
