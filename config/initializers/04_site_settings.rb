# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  # sugar
  SiteSettings = Admin::SiteSetting unless defined?(SiteSettings)
end
