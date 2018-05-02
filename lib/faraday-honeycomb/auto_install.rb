require 'faraday/honeycomb/version'

module Faraday
  module Honeycomb
    module AutoInstall
      class << self
        def available?
          gem 'faraday', ">= #{::Faraday::Honeycomb::MIN_FARADAY_VERSION}"
        rescue Gem::LoadError
          false
        end

        def auto_install!(honeycomb_client)
          require 'faraday'
          require 'faraday-honeycomb'

          Faraday::Connection.extend(Module.new do
            define_method :new do |*args|
              puts "Faraday overridden .new before super" # TODO
              block = if block_given?
                        proc do |b|
                          b.use :honeycomb, client: honeycomb_client
                          yield b
                        end
                      else
                        proc do |b|
                          b.use :honeycomb, client: honeycomb_client
                          b.adapter Faraday.default_adapter
                        end
                      end
              super(*args, &block).tap do
                puts "Faraday overridden .new after super" # TODO
              end
            end
          end)
        end
      end
    end
  end
end
