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
              block = if orig_block
                proc do |b|
                  logger.debug "Adding Faraday::Honeycomb::Middleware in #{self}.new{}" if logger
                  b.use :honeycomb, client: honeycomb_client
                  orig_block.call(b)
                end
              else
                proc do |b|
                  logger.debug "Adding Faraday::Honeycomb::Middleware in #{self}.new" if logger
                  b.use :honeycomb, client: honeycomb_client
                  b.adapter Faraday.default_adapter
                end
              end
              super(*args, &block)
            end
          end)
        end
      end
    end
  end
end
