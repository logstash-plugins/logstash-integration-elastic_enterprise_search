## 3.0.0
 - Bumped Enterprise Search clients to version `>= 7.16`, `< 9` [#18](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/18)
 - Added support to SSL configurations (`ssl_certificate_authorities`, `ssl_truststore_path`, `ssl_truststore_password`, `ssl_truststore_type`, `ssl_verification_mode`, `ssl_supported_protocols` and `ssl_cipher_suites`)
 - [BREAKING] Swiftype endpoints are no longer supported for both plugins App Search and Workplace Search
   - The App Search deprecated options `host` and `path` were removed
 - Fixed the sprintf format support for the Workplace Search `source` configuration

## 2.2.1
 - Fix, change implementation of connectivity check method to be compatible with version `v8.0+` of Workplace Search [#16](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/16) 

## 2.2.0
 - Feature, switch the connection library to elastic-enterprise-search [#3](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/3)
 - [DOC] Added required parameters to Workplace Search example snippet and describe little better what's expected in url parameter [#11](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/11)

## 2.1.2
 - [DOC] Fix typos in App Search and Workplace Search [#9](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/9)
 - [DOC] Add links to Elastic App Search and Elastic Workplace Search solution pages [#10](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/9) 

## 2.1.1
 - [DOC] Added the integration attribute and include statement for the integration plugin header to finalize hooking up integration docs [#8](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/8)
 - [DOC] Added live link to output-elastic_workplace_search doc [#6](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/6)

## 2.1.0
 - Addition of Workplace Search Output plugin [#4](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/4)
 - [DOC] Added the integration attribute and include statement for the integration plugin header to output-elastic_app_search doc [#5](https://github.com/logstash-plugins/logstash-integration-elastic_enterprise_search/pull/5)


## 2.0.0
 - Initial release of the Elastic EnterpriseSearch Integration Plugin, which carries the
   previous AppSearch Output plugin codebase; 
   independent changelogs for previous versions can be found:
    - [AppSearch Output Plugin @1.2.0](https://github.com/logstash-plugins/logstash-output-elastic_app_search/blob/v1.2.0/CHANGELOG.md)

