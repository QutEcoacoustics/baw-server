# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

Rails.application.config.session_store(
  :cookie_store,
  key: '_baw_session',
  # secure will only mark a cookie as secure if the connection is also https,
  # which it is not in dev/test.
  # It must be secure or else the samesite=none attribute fails.
  secure: !BawApp.dev_or_test?,
  # We can't set samesite to none in dev/test because the connection is not https.
  same_site: BawApp.dev_or_test? ? :lax : :none
)
