# frozen_string_literal: true

# A controller used as the base class for the CMS system
class CmsController < ApplicationController
  helper Comfy::CmsHelper
  helper CmsHelpers
end
