module LogStash::PluginMixins::EnterpriseSearch
  # This module is meant to be included in EnterpriseSearch::Clients subclasses and overrides
  # the default #transport method, changing the HTTP client to Manticore.
  # It also provides common Manticore configurations such as :ssl.
  module ManticoreTransport
    def self.included(base)
      load_transport!

      raise ArgumentError, "`#{base}` must inherit Elastic::EnterpriseSearch::Client" unless base < Elastic::EnterpriseSearch::Client
      raise ArgumentError, "`#{base}` must respond to :params" unless base.instance_methods.include? :params
    end

    # `elasticsearch-transport` is old, `elastic-transport` is the replacement.
    # LS-core updated `elasticsearch` > 8: https://github.com/elastic/logstash/pull/17161
    # Following logic supports both `elasticsearch-transport` and `elastic-transport` gems.
    def self.load_transport!
      return if @transport_loaded
      begin
        require 'elasticsearch/transport/transport/http/manticore'
        @use_legacy_transport = true
      rescue LoadError
        require 'elastic/transport/transport/http/manticore'
        @use_legacy_transport = false
      end
      @transport_loaded = true
    end

    def self.use_legacy_transport?
      @use_legacy_transport
    end

    # overrides Elastic::EnterpriseSearch::Client#transport
    def transport
      @options[:transport] || transport_klass.new(
        host: host,
        log: log,
        logger: logger,
        request_timeout: overall_timeout,
        adapter: @options[:adapter],
        transport_options: {
          request: { open_timeout: open_timeout }
        },
        transport_class: manticore_transport_klass,
        ssl: build_ssl_config,
        enable_meta_header: @options[:enable_meta_header] || true,
        trace: !@options[:tracer].nil?,
        tracer: @options[:tracer]
      )
    end

    private

    def manticore_transport_klass
      ManticoreTransport.use_legacy_transport? ? Elasticsearch::Transport::Transport::HTTP::Manticore : Elastic::Transport::Transport::HTTP::Manticore
    end

    def transport_klass
      if ManticoreTransport.use_legacy_transport?
        Elasticsearch::Transport::Client
      else
        Elastic::Transport::Client
      end
    end

    def build_transport_options
      { request: { open_timeout: open_timeout } }
    end

    def build_ssl_config
      ssl_certificate_authorities, ssl_truststore_path = params.values_at('ssl_certificate_authorities', 'ssl_truststore_path')
      if ssl_certificate_authorities && ssl_truststore_path
        raise ::LogStash::ConfigurationError, 'Use either "ssl_certificate_authorities" or "ssl_truststore_path" when configuring the CA certificate'
      end

      ssl_options = {}
      if ssl_certificate_authorities&.any?
        raise ::LogStash::ConfigurationError, 'Multiple values on "ssl_certificate_authorities" are not supported by this plugin' if ssl_certificate_authorities.size > 1

        ssl_options[:ca_file] = ssl_certificate_authorities.first
      end

      if ssl_truststore_path
        ssl_options[:truststore] = ssl_truststore_path
        ssl_options[:truststore_type] = params['ssl_truststore_type'] if params.include?('ssl_truststore_type')
        ssl_options[:truststore_password] = params['ssl_truststore_password'].value if params.include?('ssl_truststore_password')
      end

      ssl_options[:verify] = params['ssl_verification_mode'] == 'full' ? :strict : :disable
      ssl_options[:cipher_suites] = params['ssl_cipher_suites'] if params.include?('ssl_cipher_suites')
      ssl_options[:protocols] = params['ssl_supported_protocols'] if params['ssl_supported_protocols']&.any?
      ssl_options
    end
  end
end
