# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password]

Rails.application.config.filter_parameters << lambda { |k, v|
  begin
    # Bail immediately if we can
    next unless k == 'image'

    return nil if v.nil?

    if v.is_a?(ActionDispatch::Http::UploadedFile)
      return "#{ActionDispatch::Http::UploadedFile}: #{v.content_type}, #{v.original_filename}"
    end

    # Truncate the image data so we don't blast the logs
    v.replace(v[0, 100] + "[TRUNCATED-Length:#{v.length}]")
  rescue StandardError => e
    Rails.logger.error e
  end
}
