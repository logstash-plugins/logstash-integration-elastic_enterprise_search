require 'elastic-enterprise-search'
require 'logstash/plugin_mixins/enterprise_search/manticore_transport'

module LogStash::PluginMixins::EnterpriseSearch

  module AppSearch
    # App Search client for Enterprise Search.
    # This client extends Elastic::EnterpriseSearch::AppSearch::Client but overrides #transport to use Manticore.
    class Client < Elastic::EnterpriseSearch::AppSearch::Client
      attr_reader :params

      include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport

      def initialize(options, params: {})
        @params = params
        super options
      end
    end
  end

  module WorkplaceSearch
    # Workplace Search client for Enterprise Search.
    # This client extends Elastic::EnterpriseSearch::WorkplaceSearch::Client but overrides #transport to use Manticore.
    class Client < Elastic::EnterpriseSearch::WorkplaceSearch::Client
      attr_reader :params

      include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport

      def initialize(options, params: {})
        @params = params
        super options
      end
    end
  end
end
