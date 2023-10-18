require "logstash/devutils/rspec/spec_helper"
require 'logstash/plugin_mixins/enterprise_search/client'

describe LogStash::PluginMixins::EnterpriseSearch::AppSearch::Client do
  subject(:client) { described_class.new({}, params: {}) }

  it 'should inherit Elastic::EnterpriseSearch::AppSearch::Client' do
    expect(described_class.ancestors).to include(Elastic::EnterpriseSearch::AppSearch::Client)
  end

  it 'should include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport' do
    expect(described_class.ancestors).to include(LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport)
  end
end

describe LogStash::PluginMixins::EnterpriseSearch::WorkplaceSearch::Client do
  subject(:client) { described_class.new({}, params: {}) }

  it 'should inherit Elastic::EnterpriseSearch::AppSearch::Client' do
    expect(described_class.ancestors).to include(Elastic::EnterpriseSearch::WorkplaceSearch::Client)
  end

  it 'should include LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport' do
    expect(described_class.ancestors).to include(LogStash::PluginMixins::EnterpriseSearch::ManticoreTransport)
  end
end