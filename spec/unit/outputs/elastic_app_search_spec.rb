require 'logstash/devutils/rspec/spec_helper'
require 'logstash/outputs/elastic_app_search'
require 'logstash/codecs/plain'
require 'logstash/event'

describe LogStash::Outputs::ElasticAppSearch do
  let(:event) { LogStash::Event.new('message' => 'An event') }
  let(:api_key) { 'my_key' }
  let(:engine) { 'test-engine' }
  let(:config) { { 'api_key' => api_key, 'engine' => engine } }
  let(:client) { double('Client') }

  subject(:plugin) { described_class.new(config) }

  before(:each) do
    allow(plugin).to receive(:check_connection!)
    plugin.instance_variable_set(:@client, client)
  end

  describe '#register' do
    context 'when engine is defined in sprintf format' do
      let(:config) { super().merge('engine' => '%{engine_name_field}') }
      it 'does not raise an error' do
        expect { plugin.register }.to_not raise_error
      end
    end
  end

  describe '#multi_receive' do
    let(:response) { double('Response') }
    let(:response_status) { 200 }
    let(:response_body) { [{ 'errors' => [] }] }

    before(:each) do
      allow(response).to receive(:status).and_return(response_status)
      allow(response).to receive(:body).and_return(response_body)
    end

    it 'should remove @timestamp and @version fields' do
      allow(client).to receive(:index_documents) do |_, arguments|
        expect(arguments[:documents].length).to eq(1)
        expect(arguments[:documents].first).to_not include('@timestamp', '@version')
        response
      end

      plugin.multi_receive([event])
    end

    context 'with :document_id configured' do
      let(:config) { super().merge('document_id' => 'foo') }

      it 'should include `id` field' do
        allow(client).to receive(:index_documents) do |_, arguments|
          expect(arguments[:documents].length).to eq(1)
          expect(arguments[:documents].first).to include('id')
          expect(arguments[:documents].first['id']).to eq('foo')
          response
        end

        plugin.multi_receive([event])
      end
    end

    context 'with :timestamp_destination configured' do
      let(:config) { super().merge('timestamp_destination' => 'copied_timestamp') }

      it 'should copy @timestamp value to :timestamp_destination field' do
        allow(client).to receive(:index_documents) do |_, arguments|
          expect(arguments[:documents].length).to eq(1)
          expect(arguments[:documents].first).to include('copied_timestamp')
          expect(arguments[:documents].first['copied_timestamp']).to_not be_nil
          response
        end

        plugin.multi_receive([event])
      end
    end

    context 'when multiple engines are defined in sprintf format' do
      let(:response_body) { [{ 'errors' => [] }, { 'errors' => [] }] }
      let(:config) { { 'api_key' => api_key, 'engine' => '%{engine_field}' } }

      it 'should index events grouped by resolved engine' do
        event_engine_a = LogStash::Event.new('message' => 'engine_a', 'engine_field' => 'engine_a')
        event_engine_b = LogStash::Event.new('message' => 'engine_b', 'engine_field' => 'engine_b')

        allow(client).to receive(:index_documents).twice do |resolved_engine, arguments|
          docs = arguments[:documents]
          expect(docs.length).to eq(1)
          expect(arguments[:documents].first['message']).to eq(resolved_engine)
          response
        end

        plugin.multi_receive([event_engine_a, event_engine_b])
      end
    end

    context 'when indexing fail' do
      let(:response_status) { 400 }
      let(:response_body) { [{ 'errors' => ['failed'] }, { 'errors' => [] }] }

      it 'should log warn message' do
        allow(client).to receive(:index_documents).and_return(response)
        allow(plugin.logger).to receive(:warn)

        successful_event = LogStash::Event.new
        plugin.multi_receive([successful_event, event])

        successful_document = successful_event.to_hash
        successful_document.delete('@timestamp')
        successful_document.delete('@version')

        expect(plugin.logger).to have_received(:warn).with('Document failed to index. Dropping..', :document => successful_document, :errors => ['failed']).once
      end
    end
  end
end
