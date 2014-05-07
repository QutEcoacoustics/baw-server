Recaptcha.configure do |config|
  config.public_key = Settings.recaptcha.public_key
  config.private_key = Settings.recaptcha.private_key

  unless Settings.recaptcha.proxy.blank?
    config.proxy = Settings.recaptcha.proxy
  end
end