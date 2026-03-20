# frozen_string_literal: true

class ReportsController < ApplicationController
  include Api::ControllerHelper
  include Api::Reporting

  # TODO: it's not clear you are missing bucket_size from the error message if you pass empty options hash
  #   body = { options: {}, filter: {} }
  #   {"meta":{"status":422,"message":"Unprocessable Content","error":{"details":"The request could not be understood: param is missing or the value is empty or invalid: options"}},"data":null}
  #
  # POST /reports/tag_accumulation
  def tag_accumulation
    do_authorize_class(:filter, AudioEvent)

    base_query = Access::ByPermissionTable.audio_events(current_user, level: Access::Permission::READER)

    results, opts = execute_report(
      base_query:,
      template: AudioEventBucketer,
      projections: {},
      joins: { taggings: [:tag] },
      options: api_options_params.permit(:bucket_size).to_h.symbolize_keys
    )

    respond_report(results, opts)
  end
end
