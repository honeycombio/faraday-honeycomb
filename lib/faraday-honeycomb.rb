require 'faraday/honeycomb/version'

begin
  gem 'faraday', ">= #{Faraday::Honeycomb::MIN_FARADAY_VERSION}"

  require 'faraday/honeycomb'
rescue Gem::LoadError
  warn 'Faraday not detected, not enabling faraday-honeycomb'
end
