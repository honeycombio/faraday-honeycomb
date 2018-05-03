require 'faraday/honeycomb/version'

module Faraday
  module Honeycomb
    module AutoInstall
      class << self
        def available?(**_)
          gem 'faraday', ">= #{::Faraday::Honeycomb::MIN_FARADAY_VERSION}"
        rescue Gem::LoadError
          false
        end

        def auto_install!(honeycomb_client:, logger: nil)
          require 'faraday'
          require 'faraday-honeycomb'

          Faraday::Connection.extend(Module.new do
            define_method :new do |*args, &orig_block|
              block = if orig_block
                        proc do |b|
                          b.use :honeycomb, client: honeycomb_client
                          orig_block.call(b)
                        end
                      else
                        proc do |b|
                          b.use :honeycomb, client: honeycomb_client
                          b.adapter Faraday.default_adapter
                        end
                      end
              super(*args, &block).tap do
              end
            end
          end)
        end
      end
    end
  end
end
