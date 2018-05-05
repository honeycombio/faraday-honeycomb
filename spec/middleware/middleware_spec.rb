require 'faraday-honeycomb'

require 'timeout'

RSpec.describe Faraday::Honeycomb::Middleware do
  it "registers with Faraday::Middleware (to avoid that, require 'faraday/honeycomb/middleware')" do
    expect(->{
      Faraday.new('http://example.com') do |conn|
        conn.use :honeycomb
      end
    }).to_not raise_error
  end

  let(:fakehoney) { Libhoney::TestClient.new }

  let(:faraday) do
    Faraday.new('http://example.com') do |conn|
      conn.use :honeycomb, client: fakehoney
      conn.adapter :test do |stub|
        stub.get('/') { [200, {}, 'hello'] }
        stub.get('/slow') { raise Timeout::Error }
      end
    end
  end

  def emitted_event
    events = fakehoney.events
    expect(events.size).to eq(1)
    events[0]
  end

  it 'sends an event when a request is made' do
    response = faraday.get '/'
    expect(response.status).to eq(200)

    event = emitted_event
    expect(event.data).to include(
      url: 'http://example.com/',
      protocol: 'http',
      host: 'example.com',
      path: '/',
      status: 200,
    )
    expect(event.data[:durationMs]).to be_a(Numeric)
  end

  it 'records exception details if one was raised' do
    expect(->{
      faraday.get '/slow'
    }).to raise_error(Timeout::Error)

    event = emitted_event
    expect(event.data).to include(
      exception_class: Timeout::Error,
      exception_message: 'Timeout::Error',
    )
  end
end
