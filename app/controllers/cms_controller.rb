# frozen_string_literal: true

# A controller used as the base class for the CMS system
class CmsController < ApplicationController
  helper Comfy::CmsHelper
  helper CmsHelpers

  # Allows rendering CMS blobs - comfy has it's own auth modules, see the
  # initializer for details
  # @override
  def should_authenticate_user?
    false
  end

  # Override our default authorization requirement check
  def should_check_authorization?
    # yes by default unless it is the asset controller
    # (for public/admin auth details see the CMS initializer)

    return false if instance_of?(::Comfy::Cms::AssetsController)

    # and bypass checking the jump action
    # - we're already authenticated as admin
    # - jump is just a redirect
    # - normal authorization cook is not called for this controller (only its children)
    return false if instance_of?(::Comfy::Admin::Cms::BaseController) && params[:action].to_sym == :jump

    super
  end
end
