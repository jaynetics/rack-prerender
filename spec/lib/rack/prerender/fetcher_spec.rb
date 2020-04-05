
require 'spec_helper'

describe Rack::Prerender::Fetcher do
  describe '#call' do
    it 'returns a prerendered response for a crawler with the returned status code and headers' do
      request = Rack::MockRequest.env_for('http://x.com/', 'HTTP_USER_AGENT' => 'bot')
      stub_request(:get, subject.api_url('http://x.com/')).with(headers: ({ 'User-Agent' => 'bot' }))
        .to_return(body: 'prerender_body', status: 301, headers: ({ 'Location' => 'http://google.com' }))
      response = subject.call(request)
      expect(response[0]).to eq 301
      expect(response[1]).to eq('location' => 'http://google.com')
      expect(response[2]).to eq ['prerender_body']
    end
  end

  describe '#fetch_env' do
    it 'calls #fetch_url with the #request_url and request user agent' do
      request = Rack::MockRequest.env_for('/foo', 'HTTP_USER_AGENT' => 'bot')
      expect(subject).to receive(:fetch_url).with('http://example.org/foo', as: 'bot')
      subject.fetch_env(request)
    end
  end

  describe '#request_url' do
    it 'builds the correct url for the Cloudflare Flexible SSL support' do
      request = Rack::MockRequest.env_for('http://google.com/search?q=javascript', 'CF-VISITOR' => '"scheme":"https"')
      expect(subject.request_url(request)).to eq 'https://google.com/search?q=javascript'
    end

    it 'builds the correct url for the Heroku SSL Addon support with single value' do
      request = Rack::MockRequest.env_for('http://google.com/search?q=javascript', 'X-FORWARDED-PROTO' => 'https')
      expect(subject.request_url(request)).to eq 'https://google.com/search?q=javascript'
    end

    it 'builds the correct url for the Heroku SSL Addon support with double value' do
      request = Rack::MockRequest.env_for('http://google.com/search?q=javascript', 'X-FORWARDED-PROTO' => 'https,http')
      expect(subject.request_url(request)).to eq 'https://google.com/search?q=javascript'
    end

    it 'builds the correct url for the protocol option' do
      subject = Rack::Prerender::Fetcher.new(protocol: 'https')
      request = Rack::MockRequest.env_for('http://google.com/search?q=javascript')
      expect(subject.request_url(request)).to eq 'https://google.com/search?q=javascript'
    end
  end

  describe '#fetch_url' do
    it 'calls #fetch_api_uri with the #api_url and given user agent' do
      allow(subject).to receive(:api_url).and_return('bar')
      expect(subject).to receive(:fetch_api_uri).with(URI.parse('bar'), as: 'bot')
      subject.fetch_url('whatever', as: 'bot')
    end
  end

  describe '#api_url' do
    it 'builds the correct api url with the default service url' do
      expect(subject.api_url('https://google.com')).to eq 'http://service.prerender.io/https://google.com'
    end

    it 'builds the correct api url with an environment variable url' do
      ENV['PRERENDER_SERVICE_URL'] = 'http://myservice.com'
      expect(subject.api_url('https://google.com')).to eq 'http://myservice.com/https://google.com'
      ENV['PRERENDER_SERVICE_URL'] = nil
    end

    it 'builds the correct api url with an initialization variable url' do
      subject = Rack::Prerender::Fetcher.new(prerender_service_url: 'https://yourservice.com')
      expect(subject.api_url('https://google.com')).to eq 'https://yourservice.com/https://google.com'
    end
  end
end
