require 'faraday'
require 'libhoney'
require 'securerandom'

require 'faraday/honeycomb/version'

module Faraday
  module Honeycomb
    USER_AGENT_SUFFIX = "#{GEM_NAME}/#{VERSION}"

    class Middleware
      def initialize(app, client: nil, logger: nil)
        @logger = logger
        @logger ||= ::Honeycomb.logger if defined?(::Honeycomb.logger)

        honeycomb = if client
          debug "initialized with #{client.class.name} via :client option"
          client
        elsif defined?(::Honeycomb.client)
          debug "initialized with #{::Honeycomb.client.class.name} from honeycomb-beeline"
          ::Honeycomb.client
        else
          debug "initializing new Libhoney::Client"
          Libhoney::Client.new(options.merge(user_agent_addition: USER_AGENT_SUFFIX))
        end
        @builder = honeycomb.builder.
          add(
            'type' => 'http_client',
            'meta.package' => 'faraday',
            'meta.package_version' => Faraday::VERSION,
          )
        @app = app
      end

      def call(env)
        event = @builder.event

        add_request_fields(event, env)

        start = Time.now
        response = with_tracing_if_available(event, env) do
          @app.call(env)
        end

        add_response_fields(event, response)

        response
      rescue Exception => e
        if event
          event.add_field 'request.error', e.class.name
          event.add_field 'request.error_detail', e.message
        end
        raise
      ensure
        if start && event
          finish = Time.now
          duration = finish - start
          event.add_field 'duration_ms', duration * 1000
          event.send
        end
      end

      private
      def debug(msg)
        @logger.debug("#{self.class.name}: #{msg}") if @logger
      end

      def add_request_fields(event, env)
        loud_method = loud_method(env)
        event.add(
          'name' => "#{loud_method} #{env.url.host}#{env.url.path}",
          'request.method' => loud_method,
          'request.protocol' => env.url.scheme,
          'request.host' => env.url.host,
          'request.path' => env.url.path,
        )
      end

      def add_response_fields(event, response)
        event.add_field 'response.status_code', response.status
      end

      def loud_method(env)
        env.method.upcase.to_s
      end

      def with_tracing_if_available(event, env)
        # return if we are not using the ruby beeline
        return yield unless defined?(::Honeycomb)

        # beeline version <= 0.5.0
        if ::Honeycomb.respond_to? :trace_id
          trace_id = ::Honeycomb.trace_id
          event.add_field 'trace.trace_id', trace_id if trace_id
          span_id = SecureRandom.uuid
          event.add_field 'trace.span_id', span_id

          ::Honeycomb.with_span_id(span_id) do |parent_span_id|
            event.add_field 'trace.parent_id', parent_span_id
            yield
          end
        # beeline version > 0.5.0
        elsif ::Honeycomb.respond_to? :span_for_existing_event
          ::Honeycomb.span_for_existing_event event, name: nil, type: 'http_client' do |span_id, trace_id|
            add_trace_context_header(env, trace_id, span_id)
            yield
          end
        # fallback if we don't detect any known beeline tracing methods
        else
          yield
        end
      end

      def add_trace_context_header(env, trace_id, span_id)
        # beeline version > 0.5.0
        if ::Honeycomb.respond_to? :encode_trace_context
          encoded_context = ::Honeycomb.encode_trace_context(trace_id, span_id, **::Honeycomb.active_trace_context)
          env.request_headers['X-Honeycomb-Trace'] = encoded_context
        end
      end
    end
  end
end
