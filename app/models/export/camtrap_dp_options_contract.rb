# frozen_string_literal: true

class Export
  # Lightweight structural validation of Camtrap DP export options so invalid
  # options cannot be persisted. The exporter performs the full, authoritative
  # validation when the export runs.
  class CamtrapDpOptionsContract < Dry::Validation::Contract
    Types = BawWorkers::Export::CamtrapDp::Types

    json do
      required(:contributors).array(:hash) do
        optional(:organization).filled(:string)
        required(:title).filled(:string)
        optional(:email).filled(:string)
        optional(:path).filled(Types::Url)
        optional(:role).filled(Types::Role)
      end
      required(:project_capture_method).array(Types::CaptureMethod)
      required(:project_sampling_design).value(Types::SamplingDesign)
      optional(:forced_timezone).maybe(:string)
      optional(:emit_project_license).value(:bool)
    end

    rule(:contributors).each do |index:|
      next unless value.key?(:path)

      key([:contributors, index, :path]).failure('is not a valid URL') unless Types::Url.valid?(value[:path])
    end

    rule(:forced_timezone) do
      next if value.blank?

      key.failure('is not a valid timezone') unless ActiveSupport::TimeZone[value]
    end
  end
end
