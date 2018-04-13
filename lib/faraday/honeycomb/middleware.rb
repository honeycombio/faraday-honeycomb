require 'faraday'
require 'libhoney'

module Faraday
  module Honeycomb
    USER_AGENT_SUFFIX = "#{GEM_NAME}/#{VERSION}"

    class Middleware
      def initialize(app, options = {})
        @honeycomb = options[:client] || Libhoney::Client.new(options.merge(user_agent_addition: USER_AGENT_SUFFIX))
        @app = app
      end

      def call(env)
        event = @honeycomb.event

        event.add_field :url, env.url.to_s

        event.add_field :protocol, env.url.scheme
        event.add_field :host, env.url.host
        event.add_field :path, env.url.path

        start = Time.now
        response = @app.call(env)

        event.add_field :status, response.status

        response
      rescue Exception => e
        event.add_field :exception_class, e.class
        event.add_field :exception_message, e.message
        raise
      ensure
        finish = Time.now
        duration = finish - start
        event.add_field :duration_ms, duration * 1000
        event.send
      end
    end
  end
end
