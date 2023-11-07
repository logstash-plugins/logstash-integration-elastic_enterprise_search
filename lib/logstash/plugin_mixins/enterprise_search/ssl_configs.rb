module LogStash::PluginMixins::EnterpriseSearch
  # This module defines common SSL options that can be reused by the app and workplace search plugins.
  module SSLConfigs
    def self.included(base)
      # SSL Certificate Authority files in PEM encoded format, must also include any chain certificates as necessary
      base.config :ssl_certificate_authorities, :validate => :path, :list => true

      # The JKS truststore to validate the server's certificate.
      # Use either `:ssl_truststore_path` or `:ssl_certificate_authorities`
      base.config :ssl_truststore_path, :validate => :path

      # Set the truststore password
      base.config :ssl_truststore_password, :validate => :password

      # The format of the truststore file. It must be either jks or pkcs12
      base.config :ssl_truststore_type, :validate => %w[pkcs12 jks]

      # Options to verify the server's certificate.
      # "full": validates that the provided certificate has an issue date that’s within the not_before and not_after dates;
      # chains to a trusted Certificate Authority (CA); has a hostname or IP address that matches the names within the certificate.
      # "none": performs no certificate validation. Disabling this severely compromises security (https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf)
      base.config :ssl_verification_mode, :validate => %w[full none], :default => 'full'

      # Supported protocols with versions.
      base.config :ssl_supported_protocols, :validate => %w[TLSv1.1 TLSv1.2 TLSv1.3], :default => [], :list => true

      # The list of cipher suites to use, listed by priorities.
      # Supported cipher suites vary depending on which version of Java is used.
      base.config :ssl_cipher_suites, :validate => :string, :list => true
    end
  end
end
