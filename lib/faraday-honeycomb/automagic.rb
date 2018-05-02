# Alternative gem entrypoint that automagically installs our middleware into
# Faraday.

require 'faraday/honeycomb/version'

begin
  gem 'honeycomb-beeline'
  gem 'faraday', ">= #{Faraday::Honeycomb::MIN_FARADAY_VERSION}"

  require 'honeycomb-beeline/automagic'
  require 'faraday/honeycomb'

  Honeycomb.after_init :faraday do |client|
    require 'faraday'

    Faraday::Connection.extend(Module.new do
      define_method :new do |*args|
        puts "Faraday overridden .new before super"
        block = if block_given?
                  proc do |b|
                    b.use :honeycomb, client: client
                    yield b
                  end
                else
                  proc do |b|
                    b.use :honeycomb, client: client
                    b.adapter Faraday.default_adapter
                  end
                end
        super(*args, &block).tap do
          puts "Faraday overridden .new after super"
        end
      end
    end)
  end
rescue Gem::LoadError => e
  case e.name
  when 'faraday'
      puts 'Not autoinitialising faraday-honeycomb'
  when 'honeycomb'
    warn "Please ensure you `require 'faraday-honeycomb/automagic'` *after* `require 'honeycomb-beeline/automagic'`"
  end
end
