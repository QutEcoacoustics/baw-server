# frozen_string_literal: true

# A controller used as the base class for the CMS system
class CmsController < ApplicationController
  helper Comfy::CmsHelper
  helper CmsHelpers

  # Override our default authorization  requirement check
  def should_check_authorization?
    # yes by default unless it is the asset controller
    # (for public/admin auth details see the CMS initializer)

    return false if self.class.name == 'Comfy::Cms::AssetsController'

    super
  end
end
