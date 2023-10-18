require 'logstash/devutils/rspec/spec_helper'
require 'stud/temporary'
require 'logstash/plugin_mixins/enterprise_search/manticore_transport'

describe LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport do
  describe 'Client class' do
    subject(:client_class) do
      Class.new(Elastic::EnterpriseSearch::Client) do
        attr_reader :params
        include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport

        def initialize(options, params: {})
          @params = params
          super options
        end
      end
    end

    context "#transport" do
      let(:client) { client_class.new({}, params: {}) }

      it 'should override #transport' do
        expect(client.method(:transport).owner).to eq(LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport)
      end

      it 'should use manticore setting the :ssl argument' do
        ssl_config = { ssl: { verify: :disable } }
        allow(client).to receive(:build_ssl_config).and_return(ssl_config)

        result = client.transport

        if LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport.eps_version_7?
          expect(result.transport).to be_a(Elasticsearch::Transport::Transport::HTTP::Manticore)
        else
          expect(result.transport).to be_a(Elastic::Transport::Transport::HTTP::Manticore)
        end

        expect(result.instance_variable_get(:@arguments)[:ssl]).to eq(ssl_config)
      end
    end

    context '#build_ssl_config' do
      let(:params) { {} }
      let(:client) { client_class.new({}, params: params) }
      let(:built_ssl_options) { client.send(:build_ssl_config) }

      [{ param_value: 'full', client_value: :strict },
       { param_value: 'none', client_value: :disable }].each do |config|
        context "when ssl_verification_mode is `#{config[:param_value]}`" do
          let(:params) { super().merge('ssl_verification_mode' => config[:param_value]) }
          it "should set :verify to #{config[:client_value]}" do
            expect(built_ssl_options[:verify]).to eq(config[:client_value])
          end
        end
      end

      context 'when ssl_certificate_authorities is set' do
        let(:ca_path) { 'spec/fixtures/certificates/root_ca.crt'}
        let(:params) { super().merge('ssl_certificate_authorities' => [ca_path]) }

        it 'should set :ca_file' do
          expect(built_ssl_options[:ca_file]).to eq(ca_path)
        end
      end

      context 'when ssl_cipher_suites is set' do
        let(:params) { super().merge('ssl_cipher_suites' => ['TLS_FOO_BAR']) }

        it 'should set :cipher_suites' do
          expect(built_ssl_options[:cipher_suites]).to eq(['TLS_FOO_BAR'])
        end
      end

      context 'when ssl_supported_protocols is set' do
        let(:params) { super().merge('ssl_supported_protocols' => %w[TLSv1.2 TLSv1.3]) }

        it 'should set :protocols' do
          expect(built_ssl_options[:protocols]).to eq( %w[TLSv1.2 TLSv1.3])
        end
      end

      context 'when ssl_truststore options are set' do
        let(:keystore_path) { 'spec/fixtures/certificates/root_keystore.jks'}
        let(:keystore_password) { LogStash::Util::Password.new('changeme') }

        let(:params) do
          super().merge('ssl_truststore_path' => keystore_path,
                        'ssl_truststore_type' => 'jks',
                        'ssl_truststore_password' => keystore_password)
        end

        it 'should set :truststore options' do
          expect(built_ssl_options[:truststore]).to eq(keystore_path)
          expect(built_ssl_options[:truststore_type]).to eq('jks')
          expect(built_ssl_options[:truststore_password]).to eq('changeme')
        end
      end
    end
  end

  describe 'Client class with no :params' do
    subject(:client_class) { Class.new(Elastic::EnterpriseSearch::Client) }

    context 'when included' do
      it 'should raise an ArgumentError' do
        expect do
          client_class.include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport
        end.to raise_error(ArgumentError).with_message(/must respond to :params/)
      end
    end
  end

  describe 'No client class' do
    subject(:client) { Class.new }

    context 'when included' do
      it 'should raise an ArgumentError' do
        expect do
          client.include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport
        end.to raise_error(ArgumentError).with_message(/must inherit Elastic::EnterpriseSearch::Client/)
      end
    end
  end
end
