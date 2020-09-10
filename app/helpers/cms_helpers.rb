# frozen_string_literal: true

# Helpers to expose a subset of settings to our CMS views
# Use these in a CMS blob like `{{ cms:helper xxxxxxx }}`
#
# These helpers have access to the following instance variables: @cms_site, @cms_layout and @cms_page.
module CmsHelpers
  def site_name
    Settings.organisation_names.site_long_name
  end

  def parent_site_name
    Settings.organisation_names.parent_site_name
  end

  def address
    '' unless current_user

    Settings&.organisation_names&.address || '<address not configured>'
  end

  def cms_page_label
    @cms_page&.label
  end
end
