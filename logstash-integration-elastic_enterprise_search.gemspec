Gem::Specification.new do |s|
  s.name          = 'logstash-integration-elastic_enterprise_search'
  s.version         = '3.0.0'
  s.licenses        = ['Apache-2.0']
  s.summary         = "Integration with Elastic Enterprise Search - output plugins"
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline "+
                      "using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program."
  s.authors         = ["Elastic"]
  s.email           = 'info@elastic.co'
  s.homepage        = "http://www.elastic.co/guide/en/logstash/current/index.html"
  s.require_paths   = ['lib', 'vendor/jar-dependencies']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
    # Special flag to let us know this is actually a logstash plugin
  s.metadata = {
      "logstash_plugin"     => "true",
      "logstash_group"      => "integration",
      "integration_plugins" => "logstash-output-elastic_app_search, logstash-output-elastic_workplace_search"
  }

  # Gem dependencies
  s.add_runtime_dependency "manticore", '~> 0.8'
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_runtime_dependency 'elastic-enterprise-search', '>= 7.16', '< 9'
  s.add_runtime_dependency "logstash-mixin-deprecation_logger_support", '~>1.0'
  s.add_development_dependency "logstash-devutils"
end
