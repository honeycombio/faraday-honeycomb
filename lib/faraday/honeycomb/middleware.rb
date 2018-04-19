require 'faraday'
require 'libhoney'
require 'securerandom'

require 'faraday/honeycomb/version'

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
        response = adding_span_metadata_if_available(event, env) do
          @app.call(env)
        end

        event.add_field :status, response.status

        response
      rescue Exception => e
        if event
          event.add_field :exception_class, e.class
          event.add_field :exception_message, e.message
        end
        raise
      ensure
        if start && event
          finish = Time.now
          duration = finish - start
          event.add_field :durationMs, duration * 1000
          event.send
        end
      end

      private
      def adding_span_metadata_if_available(event, env)
        return yield unless defined?(::Honeycomb.trace_id)

        trace_id = ::Honeycomb.trace_id
        name = "#{env.method} #{env.url.path}"

        event.add_field :traceId, trace_id if trace_id
        span_id = SecureRandom.uuid
        event.add_field :id, span_id
        event.add_field :serviceName, 'faraday'
        event.add_field :name, name if name

        ::Honeycomb.with_span_id(span_id) do |parent_span_id|
          event.add_field :parentId, parent_span_id
          yield
        end
      end
    end
  end
end
