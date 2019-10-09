Recaptcha.configure do |config|
  config.site_key = Settings.recaptcha.public_key
  config.secret_key = Settings.recaptcha.private_key
  # Uncomment the following line if you are using a proxy server:
  # config.proxy = 'http://myproxy.com.au:8080'

  # locked to v3 API

  # disable recaptcha in development
  #config.skip_verify_env.push('development')

  unless Settings.recaptcha.proxy.blank?
    config.proxy = Settings.recaptcha.proxy
  end
end
