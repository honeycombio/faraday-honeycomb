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

        def auto_install!(honeycomb_client:, logger: nil)
          require 'faraday'
          require 'faraday-honeycomb'

          Faraday::Connection.extend(Module.new do
            define_method :new do |*args, &orig_block|
              if original_args = args.first
                if original_args.respond_to? :key
                  builder = original_args["builder"] || original_args[:builder]
                end
              end
              case
              when builder
                logger.debug "Adding Faraday::Honeycomb::Middleware in #{self}.new{}" if logger
                builder.insert(0, ::Faraday::Honeycomb::Middleware, client: honeycomb_client, logger: logger)
                super(*args, &orig_block)
              when orig_block
                block = proc do |b|
                  logger.debug "Adding Faraday::Honeycomb::Middleware in #{self}.new{}" if logger
                  b.use :honeycomb, client: honeycomb_client, logger: logger
                  orig_block.call(b)
                end
                super(*args, &block)
              else
                block = proc do |b|
                  logger.debug "Adding Faraday::Honeycomb::Middleware in #{self}.new" if logger
                  b.use :honeycomb, client: honeycomb_client, logger: logger
                  b.request :url_encoded
                  b.adapter Faraday.default_adapter
                end
              super(*args, &block)
              end
            end
          end)
        end
      end
    end
  end
end
