# frozen_string_literal: true

class Export
  # Lightweight structural validation of Camtrap DP export options so invalid
  # options cannot be persisted. The exporter performs the full, authoritative
  # validation when the export runs.
  class CamtrapDpOptionsContract < Dry::Validation::Contract
    Types = BawWorkers::Export::CamtrapDp::Types

    params do
      optional(:contributors).array(:hash) do
        optional(:organization).filled(:string)
        required(:title).filled(:string)
        optional(:email).filled(:string)
        optional(:path).filled(Types::Url)
        optional(:role).filled(Types::Role)
      end
      optional(:project_capture_method).array(Types::CaptureMethod)
      optional(:project_sampling_design).value(Types::SamplingDesign)
      optional(:forced_timezone).maybe(:string)
      optional(:emit_project_license).value(:bool)
    end

    rule(:forced_timezone) do
      next if value.blank?

      key.failure('is not a valid timezone') unless ActiveSupport::TimeZone[value]
    end
  end
end
