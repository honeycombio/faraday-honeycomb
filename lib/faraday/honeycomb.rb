require 'faraday'
require 'faraday/honeycomb/middleware'

Faraday::Middleware.register_middleware honeycomb: ->{ Faraday::Honeycomb::Middleware }
