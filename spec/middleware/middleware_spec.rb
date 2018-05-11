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
        stub.get('/slow') { raise Timeout::Error, 'too slow' }
      end
    end
  end

  let(:emitted_event) do
    events = fakehoney.events
    expect(events.size).to eq(1)
    events[0]
  end

  describe 'after the client makes a request' do
    before do
      response = faraday.get '/'
      expect(response.status).to eq(200)
    end

    it 'sends an http_client event' do
      expect(emitted_event.data).to include(
        'type' => 'http_client',
        'name' => 'GET example.com/',
      )
    end

    it 'includes basic request and response fields' do
      expect(emitted_event.data).to include(
        'request.method' => 'GET',
        'request.protocol' => 'http',
        'request.host' => 'example.com',
        'request.path' => '/',
        'response.status_code' => 200,
      )
    end

    it 'records how long the request took' do
      expect(emitted_event.data).to include('duration_ms')
      expect(emitted_event.data['duration_ms']).to be_a Numeric
    end

    it 'includes meta fields in the event' do
      expect(emitted_event.data).to include(
        'meta.package' => 'faraday',
        'meta.package_version' => Faraday::VERSION,
      )
    end
  end

  describe 'if the client raised an exception' do
    before do
      expect { faraday.get '/slow' }.to raise_error(Timeout::Error)
    end

    it 'records exception details' do
      expect(emitted_event.data).to include(
        'request.error' => 'Timeout::Error',
        'request.error_detail' => 'too slow',
      )
    end

    it 'still records how long the request took' do
      expect(emitted_event.data).to include('duration_ms')
      expect(emitted_event.data['duration_ms']).to be_a Numeric
    end
  end
end
