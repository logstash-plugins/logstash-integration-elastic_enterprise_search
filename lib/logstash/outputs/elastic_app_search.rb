# encoding: utf-8
require 'logstash/outputs/base'
require 'logstash/plugin_mixins/enterprise_search/ssl_configs'
require 'logstash/plugin_mixins/enterprise_search/client'

class LogStash::Outputs::ElasticAppSearch < LogStash::Outputs::Base

  include LogStash::PluginMixins::EnterpriseSearch::SSLConfigs

  config_name 'elastic_app_search'

  # The name of the search engine you created in App Search, an information
  # repository that includes the indexed document records.
  # The `engine` field supports
  # {logstash-ref}/event-dependent-configuration.html#sprintf[sprintf format] to
  # allow the engine name to be derived from a field value from each event, for
  # example `engine-%{engine_name}`.
  #
  # Invalid engine names cause ingestion to stop until the field value can be resolved into a valid engine name.
  # This situation can happen if the interpolated field value resolves to a value without a matching engine,
  # or, if the field is missing from the event and cannot be resolved at all.
  config :engine, :validate => :string, :required => true

  # The value of the API endpoint in the form of a URL.
  config :url, :validate => :string, :required => true, :default => Elastic::EnterpriseSearch::Utils::DEFAULT_HOST

  # The private API Key with write permissions.
  # https://www.elastic.co/guide/en/app-search/current/authentication.html#authentication-api-keys
  config :api_key, :validate => :password, :required => true

  # Where to move the value from the `@timestamp` field.
  #
  # All Logstash events contain a `@timestamp` field.
  # App Search doesn't support fields starting with `@timestamp`, and
  # by default, the `@timestamp` field will be deleted.
  #
  # To keep the timestamp field, set this value to the name of the field where you want `@timestamp` copied.
  config :timestamp_destination, :validate => :string

  # The id for app search documents. This can be an interpolated value
  # like `myapp-%{sequence_id}`. Reusing ids will cause documents to be rewritten.
  config :document_id, :validate => :string

  ENGINE_WITH_SPRINTF_REGEX = /^.*%\{.+\}.*$/.freeze

  def register
    @retry_disabled = false
    @client = LogStash::PluginMixins::EnterpriseSearch::AppSearch::Client.new(client_options, params: params)
    check_connection!
  rescue => e
    if e.message =~ /401/
      raise ::LogStash::ConfigurationError, "Failed to connect to App Search. Please check your credentials. Error: #{e.message}"
    elsif e.message =~ /404/
      raise ::LogStash::ConfigurationError, "Failed to connect to App Search. Please check if url '#{@url}' is correct and you've created an engine with name '#{@engine}'. Error: #{e.message}"
    else
      raise ::LogStash::ConfigurationError, "Failed to connect to App Search. Error: #{e.message}"
    end
  end

  def multi_receive(events)
    # because App Search has a limit of 100 documents per bulk
    events.each_slice(100) do |events|
      batch = format_batch(events)
      if @logger.trace?
        @logger.trace('Sending bulk to App Search', :size => batch.size, :data => batch.inspect)
      end
      index(batch)
    end
  end

  private

  def client_options
    options = { :host => @url, :http_auth => @api_key.value }
    options[:logger] = @logger if @logger.debug?
    options[:tracer] = @logger if @logger.trace?
    options
  end

  def format_batch(events)
    docs_for_engine = {}
    events.each do |event|
      doc = event.to_hash
      # we need to remove default fields that start with "@"
      # since Elastic App Search doesn't accept them
      if @timestamp_destination
        doc[@timestamp_destination] = doc.delete('@timestamp')
      else # delete it
        doc.delete('@timestamp')
      end
      if @document_id
        doc['id'] = event.sprintf(@document_id)
      end
      doc.delete('@version')
      resolved_engine = event.sprintf(@engine)
      unless docs_for_engine[resolved_engine]
        if @logger.debug?
          @logger.debug('Creating new engine segment in batch to send', :resolved_engine => resolved_engine)
        end
        docs_for_engine[resolved_engine] = []
      end
      docs_for_engine[resolved_engine] << doc
    end
    docs_for_engine
  end

  def index(docs_partitioned_by_engine)
    docs_partitioned_by_engine.each do |resolved_engine, documents|
      begin
        if resolved_engine =~ ENGINE_WITH_SPRINTF_REGEX || resolved_engine =~ /^\s*$/
          raise "Cannot resolve engine field name #{@engine} from event"
        end

        response = @client.index_documents(resolved_engine, { :documents => documents })
        report(documents, response)
      rescue => e
        @logger.error('Failed to execute index operation.', :exception => e.class, :reason => e.message,
                      :resolved_engine => resolved_engine, :backtrace => e.backtrace, :retry => !@retry_disabled)

        raise e if @retry_disabled

        sleep(1)
        retry
      end
    end
  end

  def report(documents, response)
    documents.each_with_index do |document, i|
      errors = response.body[i]['errors']
      if errors.empty?
        @logger.trace? && @logger.trace('Document was indexed with no errors', :document => document)
      else
        @logger.warn('Document failed to index. Dropping..', :document => document, :errors => errors.to_a)
      end
    end
  end

  def check_connection!
    res = @client.list_engines({ 'page[size]': 1 })
    raise "Received HTTP error code #{res.status}" unless res.status == 200
  end
end
