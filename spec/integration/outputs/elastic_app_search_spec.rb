# encoding: utf-8
require 'logstash/devutils/rspec/spec_helper'
require 'logstash/codecs/plain'
require 'logstash/event'
require 'json'

describe 'indexing against running App Search', :integration => true do

  require 'logstash/outputs/elastic_app_search'

  let(:url) { ENV['ENTERPRISE_SEARCH_URL'] }
  let(:private_api_key) { ENV['APP_SEARCH_PRIVATE_KEY'] }
  let(:search_api_key) { ENV['APP_SEARCH_SEARCH_KEY'] }

  let(:engine_name) do
    (0...10).map { ('a'..'z').to_a[rand(26)] }.join
  end

  let(:config) do
    {
      'api_key' => private_api_key,
      'engine' => engine_name,
      'url' => url
    }
  end

  subject(:app_search_output) { LogStash::Outputs::ElasticAppSearch.new(config) }

  before(:each) do
    create_engine(engine_name)
  end

  private

  describe 'search and private keys are configured' do
    let(:api_key_settings) do
      {
        :private => private_api_key,
        :search => search_api_key
      }
    end

    it 'setup api keys' do
      expect(api_key_settings[:private]).to start_with('private-')
      expect(api_key_settings[:search]).to start_with('search-')
    end
  end

  describe 'indexing' do
    let(:config) { super().merge('ssl_verification_mode' => 'none') }
    let(:total_property_keys) { %w[meta page total_pages] }
    let(:register) { true }

    before(:each) { app_search_output.register if register }

    describe 'single event' do
      let(:event) { LogStash::Event.new('message' => 'an event to index') }

      it 'should be indexed' do
        app_search_output.multi_receive([event])
        expect_indexed(engine_name, 1, total_property_keys)
      end

      context 'using sprintf-ed engine' do
        let(:config) { super().merge('engine' => '%{engine_name_field}') }
        let(:event) { LogStash::Event.new('message' => 'an event to index', 'engine_name_field' => engine_name) }

        it 'should be indexed' do
          app_search_output.multi_receive([event])
          expect_indexed(engine_name, 1, total_property_keys)
        end
      end
    end

    describe 'multiple events' do
      context 'single static engine' do
        let(:events) { generate_events(200) } #2 times the slice size used to batch

        it 'all should be indexed' do
          app_search_output.multi_receive(events)
          expect_indexed(engine_name, 200)
        end
      end

      context 'with sprintf engines' do
        let(:config) { super().merge('engine' => '%{engine_name_field}') }

        it 'all should be indexed' do
         create_engine('testengin1')
         create_engine('testengin2')
         events = generate_events(100, 'testengin1')
         events += generate_events(100, 'testengin2')
         events.shuffle!

         app_search_output.multi_receive(events)

         expect_indexed('testengin1', 100)
         expect_indexed('testengin2', 100)
        end
      end
    end

    describe 'with ssl enabled using a self-signed certificate', :secure_integration => true do
      let(:ca_cert) { 'spec/fixtures/certificates/root_ca.crt' }
      let(:event_message) { 'an event to index with ssl enabled' }
      let(:event) { LogStash::Event.new('message' => event_message) }

      context 'and ssl_verification_mode set to `full`' do
        let(:config) { super().merge('ssl_verification_mode' => 'full') }
        let(:register) { false }

        it 'should raise an error' do
          allow(app_search_output).to receive(:check_connection!).and_return(nil)
          app_search_output.register
          app_search_output.instance_variable_set(:@retry_disabled, true)

          expect { app_search_output.multi_receive([event]) }.to raise_error(/PKIX path/)
        end
      end

      context 'and ssl_certificate_authorities set to a valid CA' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert) }
        it 'should be indexed' do
          app_search_output.multi_receive([event])
          expect_indexed(engine_name, 1, %w[meta page total_pages], event_message)
        end
      end

      context 'and ssl_truststore_path set to a valid CA' do
        let(:config) do
          super().merge(
            'ssl_truststore_path' => 'spec/fixtures/certificates/root_keystore.jks',
            'ssl_truststore_password' => 'changeme'
          )
        end

        it 'should be indexed' do
          app_search_output.multi_receive([event])
          expect_indexed(engine_name, 1, %w[meta page total_pages], event_message)
        end
      end

      context 'and ssl_supported_protocols configured' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert, 'ssl_supported_protocols' => 'TLSv1.3') }

        it 'should be indexed' do
          app_search_output.multi_receive([event])
          expect_indexed(engine_name, 1, %w[meta page total_pages], event_message)
        end
      end

      context 'and ssl_cipher_suites configured' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert, 'ssl_cipher_suites' => 'TLS_AES_256_GCM_SHA384') }

        it 'should be indexed' do
          app_search_output.multi_receive([event])
          expect_indexed(engine_name, 1, %w[meta page total_pages], event_message)
        end
      end
    end

    private

    def execute_search_call(engine_name)
      faraday_client.post("#{url}/api/as/v1/engines/#{engine_name}/search",
                          '{"query": "event"}',
                          'Content-Type' => 'application/json',
                          'Authorization' => "Bearer #{private_api_key}")
    end

    def expect_indexed(engine_name, total_expected, total_property_keys = %w[meta page total_results], message_prefix = 'an event to index')
      results = Stud.try(20.times, RSpec::Expectations::ExpectationNotMetError) do
        attempt_response = execute_search_call(engine_name)
        expect(attempt_response.status).to eq(200)
        parsed_resp = JSON.parse(attempt_response.body)
        expect(parsed_resp.dig(*total_property_keys)).to eq(total_expected)
        parsed_resp['results']
      end

      expect(results.first.dig('message', 'raw')).to start_with(message_prefix)
    end

    def generate_events(num_events, engine_name = nil)
      (1..num_events).map do |i|
        if engine_name
          LogStash::Event.new('message' => "an event to index #{i}", 'engine_name_field' => engine_name)
        else
          LogStash::Event.new('message' => "an event to index #{i}")
        end
      end
    end
  end

  private

  def faraday_client
    Faraday.new url, ssl: { verify: false }
  end

  def create_engine(engine_name)
    resp = faraday_client.post("#{url}/api/as/v1/engines",
                               "{\"name\": \"#{engine_name}\"}",
                               'Content-Type' => 'application/json',
                               'Authorization' => "Bearer #{private_api_key}")

    expect(resp.status).to eq(200)
  end
end
