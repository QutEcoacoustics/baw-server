Recaptcha.configure do |config|
  config.public_key = Settings.recaptcha.public_key
  config.private_key = Settings.recaptcha.private_key
  # Uncomment the following line if you are using a proxy server:
  # config.proxy = 'http://myproxy.com.au:8080'
  # Uncomment if you want to use the newer version of the API,
  # only works for versions >= 0.3.7:
  config.api_version = 'v2'

  # disable recaptcha in development
  config.skip_verify_env.push('development')

  unless Settings.recaptcha.proxy.blank?
    config.proxy = Settings.recaptcha.proxy
  end
end