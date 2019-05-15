require 'faraday/honeycomb/version'

module Faraday
  module Honeycomb
    module AutoInstall
      class << self
        def available?(logger: nil)
          constraint = ">= #{::Faraday::Honeycomb::MIN_FARADAY_VERSION}"
          gem 'faraday', constraint
          logger.debug "#{self.name}: detected Faraday #{constraint}, okay to autoinitialise" if logger
          true
        rescue Gem::LoadError => e
          logger.debug "Didn't detect Faraday #{constraint} (#{e.class}: #{e.message}), not autoinitialising faraday-honeycomb" if logger
          false
        end

        def ensure_middleware_in_builder!(builder, client, logger)
          if builder.handlers.any? { |m| m.klass == ::Faraday::Honeycomb::Middleware }
            logger.debug "Faraday::Honeycomb::Middleware already exists in Faraday middleware" if logger
            return
          end

          # In faraday < 1.0 the adapter is added directly to handlers, so we
          # need to find it in the stack and insert honeycomb's middleware
          # before it
          #
          # In faraday >= 1.0 the adapter will never be in the list of
          # handlers, and will _always_ be the last thing called in the
          # middleware stack, so we need to handle it not being present.
          # https://github.com/lostisland/faraday/pull/750
          index_of_first_adapter = (builder.handlers || [])
            .find_index { |h| h.klass.ancestors.include? Faraday::Adapter }

          if index_of_first_adapter
            logger.debug "Adding Faraday::Honeycomb::Middleware before adapter" if logger
            builder.insert_before(
              index_of_first_adapter,
              Faraday::Honeycomb::Middleware,
              client: client, logger: logger
            )
          else
            logger.debug "Appending Faraday::Honeycomb::Middleware to stack" if logger
            builder.use Faraday::Honeycomb::Middleware, client: client, logger: logger
          end
        end

        def auto_install!(honeycomb_client:, logger: nil)
          require 'faraday'
          require 'faraday-honeycomb'

          Faraday::Connection.extend(Module.new do
            define_method :new do |*args, &orig_block|
              # If there are two arguments the first argument might be an
              # options hash, or a URL. The last argument in the array is
              # always an instance of `ConnectionOptions`.
              options = args.reduce({}) do |out, arg|
                out.merge!(arg.to_hash) if arg.respond_to? :to_hash
                out
              end

              builder = options["builder"] || options[:builder]

              if !builder
                # This is the configuration that would be applied if someone
                # created faraday without a config block/builder. We need to specify it
                # here because our monkeypatch causes a block to _always_ be
                # passed to Faraday
                # https://github.com/lostisland/faraday/blob/v0.15.4/lib/faraday/rack_builder.rb#L56-L60
                orig_block ||= proc do |c|
                  c.request :url_encoded
                  c.adapter Faraday.default_adapter
                end
              end

              # Always add honeycomb middleware after the middleware stack has
              # been resolved by the original block/any defaults that are
              # applied by Faraday
              block = proc do |b|
                orig_block.call(b) if orig_block

                Honeycomb::AutoInstall.ensure_middleware_in_builder!(b.builder, honeycomb_client, logger)
              end

              super(*args, &block)
            end
          end)
        end
      end
    end
  end
end
