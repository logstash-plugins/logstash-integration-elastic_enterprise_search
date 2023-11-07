# encoding: utf-8
require 'logstash/outputs/base'
require 'logstash/plugin_mixins/enterprise_search/client'
require 'logstash/plugin_mixins/enterprise_search/ssl_configs'

class LogStash::Outputs::ElasticWorkplaceSearch < LogStash::Outputs::Base

  include LogStash::PluginMixins::EnterpriseSearch::SSLConfigs

  config_name 'elastic_workplace_search'

  # The value of the API endpoint in the form of a URL.
  config :url, :validate => :string, :required => true, :default => Elastic::EnterpriseSearch::Utils::DEFAULT_HOST

  # The ID of the source you created in Workplace Search.
  # The `source` field supports
  # {logstash-ref}/event-dependent-configuration.html#sprintf[sprintf format] to
  # allow the source ID to be derived from a field value from each event, for
  # example `%{source_id}`.
  #
  # Invalid source IDs cause ingestion to stop until the field value can be resolved into a valid source ID.
  # This situation can happen if the interpolated field value resolves to a value without a matching source,
  # or, if the field is missing from the event and cannot be resolved at all.
  config :source, :validate => :string, :required => true

  # The source access token. Visit the source overview page in the Workplace Search dashboard
  # to find the token associated with your source.
  config :access_token, :validate => :password, :required => true

  # Where to move the value from the `@timestamp` field.
  #
  # All Logstash events contain a `@timestamp` field.
  # Workplace Search doesn't support fields starting with `@timestamp`, and
  # by default, the `@timestamp` field will be deleted.
  #
  # To keep the timestamp field, set this value to the name of the field where you want `@timestamp` copied.
  config :timestamp_destination, :validate => :string

  # The id for workplace search documents. This can be an interpolated value
  # like `myapp-%{sequence_id}`. Reusing ids will cause documents to be rewritten.
  config :document_id, :validate => :string

  SOURCE_WITH_SPRINTF_REGEX = /^.*%\{.+\}.*$/.freeze

  def register
    @retry_disabled = false
    @client = LogStash::PluginMixins::EnterpriseSearch::WorkplaceSearch::Client.new(client_options, params: params)
    begin
      check_connection!
    rescue => e
      raise ::LogStash::ConfigurationError, "Failed to connect to Workplace Search. Error: #{e.message}"
    end
  end

  def multi_receive(events)
    # because Workplace Search has a limit of 100 documents per bulk
    events.each_slice(100) do |events|
      batch = format_batch(events)
      @logger.trace('Sending bulk to Workplace Search', :size => batch.size, :data => batch.inspect) if @logger.trace?
      index(batch)
    end
  end

  private

  def client_options
    options = { :host => @url, :http_auth => @access_token.value }
    options[:logger] = @logger if @logger.debug?
    options[:tracer] = @logger if @logger.trace?
    options
  end

  def format_batch(events)
    docs_per_source = {}
    events.map do |event|
      doc = event.to_hash
      # we need to remove default fields that start with "@"
      # since Elastic Workplace Search doesn't accept them
      if @timestamp_destination
        doc[@timestamp_destination] = doc.delete('@timestamp')
      else # delete it
        doc.delete('@timestamp')
      end

      doc['id'] = event.sprintf(@document_id) if @document_id
      doc.delete('@version')

      resolved_source = event.sprintf(@source)
      unless docs_per_source[resolved_source]
        @logger.debug('Creating new source segment in batch to send', resolved_source: resolved_source) if @logger.debug?
        docs_per_source[resolved_source] = []
      end
      docs_per_source[resolved_source] << doc
    end

    docs_per_source
  end

  def index(docs_partitioned_by_source)
    docs_partitioned_by_source.each do |resolved_source, documents|
      begin
        raise "Cannot resolve source field name #{@source} from event" unless resolved?(resolved_source)

        response = @client.index_documents(resolved_source, { :documents => documents })
        report(documents, response)
      rescue => e
        @logger.error('Failed to execute index operation.', :exception => e.class, :reason => e.message,
                      :resolved_source => resolved_source, :backtrace => e.backtrace, :retry => !@retry_disabled)

        raise e if @retry_disabled

        sleep(1)
        retry
      end
    end
  end

  def resolved?(source)
    !(source =~ SOURCE_WITH_SPRINTF_REGEX) && !(source =~ /^\s*$/)
  end

  def report(documents, response)
    documents.each_with_index do |document, i|
      errors = response.body&.dig('results', i, 'errors')
      if errors&.empty?
        @logger.trace? && @logger.trace('Document was indexed with no errors', :document => document)
      else
        @logger.warn('Document failed to index. Dropping..', :document => document, :errors => errors.to_a)
      end
    end
  end

  def check_connection!
    res = @client.list_content_sources({ 'page[size]': 1 })
    raise "Received HTTP error code #{res.status}" unless res.status == 200
  end
end
