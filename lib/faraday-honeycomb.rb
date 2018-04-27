# Main gem entrypoint (see also lib/faraday-honeycomb/automagic.rb for an
# alternative entrypoint).

require 'faraday/honeycomb/version'

begin
  gem 'faraday', ">= #{Faraday::Honeycomb::MIN_FARADAY_VERSION}"

  require 'faraday/honeycomb'
rescue Gem::LoadError
  warn 'Faraday not detected, not enabling faraday-honeycomb'
end
