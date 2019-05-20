require 'faraday-honeycomb'
# Do not require honeycomb-beeline directly as that will auto-install our faraday middleware
require 'honeycomb/client'
require 'honeycomb/span'

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

  let(:propagated_header) { "" }

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

  describe 'outgoing trace propagation' do
    def headers_from_outgoing_request
      headers = nil

      faraday = Faraday.new('http://example.com') do |conn|
        conn.use :honeycomb, client: fakehoney
        conn.adapter :test do |stub|
          stub.get('/') {|env| headers = env.request_headers; [200, {}, 'hello'] }
        end
      end

      faraday.get '/'

      headers
    end

    context 'when executed in a request that received propagated tracing data' do
      let(:incoming_trace_metadata) {
        '1;trace_id=d2eb2028-193e-40e9-a2c1-fe0f12a4f2af,parent_id=8618cc79-b9b9-4e08-8804-c954d7db3b64,dataset=custom.dataset,context=eyJ3b3ciOiJzdWNoIG1ldGEifQ=='
      }

      it 'propagates a trace header containing details from the incoming HTTP request' do
        Honeycomb.trace_from_encoded_context(incoming_trace_metadata) do
          trace_header = headers_from_outgoing_request.fetch('X-Honeycomb-Trace')

          parsed = Honeycomb.decode_trace_context(trace_header)

          expect(parsed[:trace_id]).to eq("d2eb2028-193e-40e9-a2c1-fe0f12a4f2af")
          expect(parsed[:context]).to include({"wow" => "such meta"})
          # TODO: seems honeycomb-beeline does not support the `dataset` keyword?
        end
      end

      it 'propagates the ID of the faraday span as the trace parent_id' do
        Honeycomb.trace_from_encoded_context(incoming_trace_metadata) do
          trace_header = headers_from_outgoing_request.fetch('X-Honeycomb-Trace')

          parsed = Honeycomb.decode_trace_context(trace_header)

          expect(parsed[:parent_span_id]).to eq(emitted_event.data['trace.span_id'])
        end
      end
    end
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
      expect(emitted_event.data['duration_ms']).to be > 0
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
