require 'faraday'
require 'faraday-honeycomb'
require 'faraday-honeycomb/auto_install'

RSpec.describe Faraday::Honeycomb::AutoInstall, auto_install: true do
  before(:all) do
    Faraday::Honeycomb::AutoInstall.auto_install!(honeycomb_client: Libhoney::TestClient.new)
  end

  it "standard usage with no block works" do
    f = Faraday.new("http://honeycomb.io")
    expect(f.builder.handlers).to eq([
      Faraday::Request::UrlEncoded,
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end

  it "providing a builder with string key works" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.request :retry
      builder.adapter Faraday.default_adapter
    end
    f = Faraday.new("builder" => stack)

    expect(f.builder.handlers).to eq([
      Faraday::Request::Retry,
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end

  it "providing a builder with symbol key works" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.request :retry
      builder.adapter Faraday.default_adapter
    end
    f = Faraday.new(builder: stack)

    expect(f.builder.handlers).to eq([
      Faraday::Request::Retry,
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end

  it "providing a builder that only has an adapter works" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.adapter Faraday.default_adapter
    end
    f = Faraday.new(builder: stack)

    expect(f.builder.handlers).to eq([
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end

  it "providing a builder AND url works" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.request :retry
      builder.adapter Faraday.default_adapter
    end
    f = Faraday.new("https://example.com", builder: stack)

    expect(f.builder.handlers).to eq([
      Faraday::Request::Retry,
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end

  it "does not attempt to add honeycomb middleware if it already exists in the passed builder" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.adapter Faraday.default_adapter
    end
    f = Faraday.new(builder: stack)
    # force the builder to lock the middleware stack
    f.builder.app

    expect(f.builder.handlers).to eq([Faraday::Honeycomb::Middleware, Faraday::Adapter::NetHttp])

    f2 = Faraday.new(builder: stack)
    # force the builder to lock the middleware stack
    f2.builder.app

    expect(f2.builder.handlers).to eq([Faraday::Honeycomb::Middleware, Faraday::Adapter::NetHttp])
  end

  it "providing a builder and a block works" do
    stack = Faraday::RackBuilder.new do |builder|
      builder.response :logger
    end
    f = Faraday.new(builder: stack) do |faraday|
      faraday.request  :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    expect(f.builder.handlers).to eq([
      Faraday::Response::Logger,
      Faraday::Request::UrlEncoded,
      Faraday::Honeycomb::Middleware,
      Faraday::Adapter::NetHttp
    ])
  end
end
