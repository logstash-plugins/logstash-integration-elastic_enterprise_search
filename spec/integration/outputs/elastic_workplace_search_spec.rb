# encoding: utf-8
require 'logstash/devutils/rspec/spec_helper'
require 'logstash/codecs/plain'
require 'logstash/event'
require 'json'
require 'base64'

describe 'indexing against running Workplace Search', :integration => true do

  require 'logstash/outputs/elastic_workplace_search'

  let(:is_version7) { ENV['ELASTIC_STACK_VERSION'].strip.start_with?('7') }
  let(:url) { ENV['ENTERPRISE_SEARCH_URL'] }
  let(:username) { ENV['ENTERPRISE_SEARCH_USERNAME'] }
  let(:password) { ENV['ENTERPRISE_SEARCH_PASSWORD'] }
  let(:basic_auth_header) { Base64.strict_encode64("#{username}:#{password}") }
  let(:access_token) { fetch_access_token }
  let(:source_id) { fetch_source_id }
  let(:config) do
    {
      'url' => url,
      'source' => source_id,
      'access_token' => access_token
    }
  end

  subject(:workplace_search_output) { LogStash::Outputs::ElasticWorkplaceSearch.new(config) }

  describe 'indexing' do
    let(:config) { super().merge('ssl_verification_mode' => 'none') }
    let(:total_property_keys) { %w[meta page total_pages] }
    let(:register) { true }

    before(:each) { workplace_search_output.register if register }

    describe 'single event' do
      let(:event_message) { 'an event to index' }
      let(:event) { LogStash::Event.new('message' => event_message) }

      it 'should be indexed' do
        workplace_search_output.multi_receive([event])
        expect_indexed(1, total_property_keys, event_message)
      end

      context 'using sprintf-ed source' do
        let(:config) { super().merge('source' => '%{source_field}') }
        let(:event) { LogStash::Event.new('message' => 'an sprintf-ed event', 'source_field' => source_id) }

        it 'should be indexed' do
          workplace_search_output.multi_receive([event])
          expect_indexed(1, total_property_keys, 'an sprintf-ed event')
        end
      end
    end

    describe 'multiple events' do
      let(:events) { generate_events(200, 'multiple events to index') } # 2 times the slice size used to batch

      it 'all should be indexed' do
        workplace_search_output.multi_receive(events)
        expect_indexed(200, %w[meta page total_results], 'multiple events to index')
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
          allow(workplace_search_output).to receive(:check_connection!).and_return(nil)
          workplace_search_output.register
          workplace_search_output.instance_variable_set(:@retry_disabled, true)

          expect { workplace_search_output.multi_receive([event]) }.to raise_error(/PKIX path/)
        end
      end

      context 'and ssl_certificate_authorities set to a valid CA' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert) }
        it 'should be indexed' do
          workplace_search_output.multi_receive([event])
          expect_indexed( 1, total_property_keys, event_message)
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
          workplace_search_output.multi_receive([event])
          expect_indexed(1, total_property_keys, event_message)
        end
      end

      context 'and ssl_supported_protocols configured' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert, 'ssl_supported_protocols' => 'TLSv1.3') }

        it 'should be indexed' do
          workplace_search_output.multi_receive([event])
          expect_indexed(1, total_property_keys, event_message)
        end
      end

      context 'and ssl_cipher_suites configured' do
        let(:config) { super().merge('ssl_certificate_authorities' => ca_cert, 'ssl_cipher_suites' => 'TLS_AES_256_GCM_SHA384') }

        it 'should be indexed' do
          workplace_search_output.multi_receive([event])
          expect_indexed(1, total_property_keys, event_message)
        end
      end
    end
  end

  private

  def execute_search_call
    faraday_client.post(
      "#{url}/ws/org/sources/#{source_id}/documents",
      nil,
      'Accept' => 'application/json',
      'Authorization' => "Basic #{basic_auth_header}"
    )
  end

  def generate_events(num_events, message_prefix = 'an event to index')
    (1..num_events).map { |i| LogStash::Event.new('message' => "#{message_prefix} #{i}") }
  end

  def faraday_client
    Faraday.new(url, ssl: { verify: false })
  end

  def fetch_access_token
    if is_version7
      response = faraday_client.get("#{url}/api/ws/v1/whoami",
                                    { 'get_token' => true },
                                    { 'Content-Type' => 'application/json',
                                      'Accept' => 'application/json',
                                      'Authorization' => "Basic #{basic_auth_header}" })

      return JSON.load(response.body).fetch('access_token')
    end

    client = faraday_client
    client.headers['Authorization'] = "Basic #{basic_auth_header}"
    response = client.post('/ws/org/api_tokens',
                           '{"name":"ls-integration-test-key"}',
                           { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })

    response_json = JSON.load(response.body)
    # when a key with the name already exists, retrieve it
    if response_json.key?('errors') && response_json['errors'].include?('Name is already taken')
      response = client.get('/ws/org/api_tokens', nil, { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
      response_json = JSON.load(response.body)['results'].find { |res| res['id'] == 'ls-integration-test-key' }
    end

    client.close
    response_json.fetch('key')
  end

  def fetch_source_id
    response = faraday_client.post("#{url}/api/ws/v1/sources",
                                   JSON.dump('service_type' => 'custom', 'name' => 'whatever'),
                                   { 'Content-Type' => 'application/json',
                                     'Accept' => 'application/json',
                                     'Authorization' => "Bearer #{access_token}" })

    source_response_json = JSON.load(response.body)
    source_response_json.fetch('id')
  end

  def expect_indexed(total_expected, total_property_keys, expected_message_prefix)
    results = Stud.try(20.times, RSpec::Expectations::ExpectationNotMetError) do
      attempt_response = execute_search_call
      expect(attempt_response.status).to eq(200)
      parsed_resp = JSON.parse(attempt_response.body)
      expect(parsed_resp.dig(*total_property_keys)).to eq(total_expected)
      parsed_resp['results']
    end
    expect(results.first.fetch('message')).to start_with(expected_message_prefix)
  end
end
