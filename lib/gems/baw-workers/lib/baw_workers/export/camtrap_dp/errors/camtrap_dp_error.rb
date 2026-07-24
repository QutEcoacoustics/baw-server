# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Errors
        # Base class for Camtrap DP export errors.
        class CamtrapDpError < StandardError; end

        class ProjectLicenseError < CamtrapDpError; end
        class ValidationError < CamtrapDpError; end

        class PackageLoadError < ValidationError; end
        class DescriptorValidationError < ValidationError; end
        class CsvValidationError < ValidationError; end
      end
    end
  end
end
