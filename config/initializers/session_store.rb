# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

Rails.application.config.session_store(
  :cookie_store,
  key: '_baw_session',
  # secure will only mark a cookie as secure
  secure: !BawApp.dev_or_test?
)
