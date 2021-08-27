# frozen_string_literal: true

# if you change settings here, be sure to synchronize them with those in
# BawWorkers::Config.configure_active_storage

Rails.application.config.active_storage.service = :local
Rails.application.config.active_storage.variant_processor = :mini_magick
Rails.application.config.active_storage.queues.analysis = Settings.actions.active_storage.queue
Rails.application.config.active_storage.queues.purge = Settings.actions.active_storage.queue

# The redirect mode could be useful but we're currently only using local disk so stay with proxy
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
