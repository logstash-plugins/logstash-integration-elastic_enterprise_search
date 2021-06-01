# encoding: utf-8
require "logstash/outputs/base"
require "elastic-workplace-search"

class LogStash::Outputs::ElasticWorkplaceSearch < LogStash::Outputs::Base
  config_name "elastic_workplace_search"

  # The value of the API endpoint in the form of a URL.
  config :url, :validate => :string, :required => true

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

  public
  def register
    Elastic::WorkplaceSearch.endpoint = "#{@url.chomp('/')}/api/ws/v1/"
    @client = Elastic::WorkplaceSearch::Client.new(:access_token => @access_token.value)
    check_connection!
  rescue Elastic::WorkplaceSearch::InvalidCredentials
    raise ::LogStash::ConfigurationError.new("Failed to connect to Workplace Search. Error: 401. Please check your credentials")
  rescue Elastic::WorkplaceSearch::NonExistentRecord
    raise ::LogStash::ConfigurationError.new("Failed to connect to Workplace Search. Error: 404. Please check if url '#{@url}' is correct and you've created a source with ID '#{@source}'")
  rescue => e
    raise ::LogStash::ConfigurationError.new("Failed to connect to Workplace Search. #{e.message}")
  end

  public
  def multi_receive(events)
    # because Workplace Search has a limit of 100 documents per bulk
    events.each_slice(100) do |events|
      batch = format_batch(events)
      if @logger.trace?
        @logger.trace("Sending bulk to Workplace Search", :size => batch.size, :data => batch.inspect)
      end
      index(batch)
    end
  end

  private
  def format_batch(events)
    events.map do |event|
      doc = event.to_hash
      # we need to remove default fields that start with "@"
      # since Elastic Workplace Search doesn't accept them
      if @timestamp_destination
        doc[@timestamp_destination] = doc.delete("@timestamp")
      else # delete it
        doc.delete("@timestamp")
      end
      if @document_id
        doc["id"] = event.sprintf(@document_id)
      end
      doc.delete("@version")
      doc
    end
  end

  def index(documents)
    response = @client.index_documents(@source, documents)
    report(documents, response)
  rescue => e
    @logger.error("Failed to execute index operation. Retrying..", :exception => e.class, :reason => e.message)
    sleep(1)
    retry
  end

  def report(documents, response)
    documents.each_with_index do |document, i|
      errors = response["results"][i]["errors"]
      if errors.empty?
        @logger.trace? && @logger.trace("Document was indexed with no errors", :document => document)
      else
        @logger.warn("Document failed to index. Dropping..", :document => document, :errors => errors.to_a)
      end
    end
  end

  def check_connection!
    @client.list_all_permissions(@source)
  end
end
