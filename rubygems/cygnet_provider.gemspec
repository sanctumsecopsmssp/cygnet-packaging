# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'cygnet_provider'
  spec.version     = '0.1.5'
  spec.summary     = 'OpenSSL 3 provider module supplying the CYGNET MAC algorithms'
  spec.description = <<~DESC
    Installs the Cygnet OpenSSL 3 provider module, which supplies CYGNET-HMAC,
    CYGNET-CMAC, CYGNET-KMAC-128, and CYGNET-KMAC-256. Those algorithms delegate
    to the FIPS provider where one is available.

    The binary is not bundled. RubyGems has no post-install hook, so the
    extension step downloads the artifact for the running platform from the
    cygnet-provider GitHub release and verifies it against that release's
    signed SHA256SUMS manifest.
  DESC
  spec.authors  = ['Sanctum SecOps LLC']
  spec.email    = ['support@sanctumsecops.com']
  spec.homepage = 'https://github.com/sanctumsecopsmssp/cygnet-provider'
  spec.license  = 'Apache-2.0'

  spec.required_ruby_version = '>= 3.0'

  spec.files = [
    'cygnet_provider.gemspec',
    'lib/cygnet_provider.rb',
    'ext/cygnet_provider/extconf.rb'
  ]
  spec.require_paths = ['lib']
  spec.extensions    = ['ext/cygnet_provider/extconf.rb']

  spec.metadata = {
    'github_repo' => 'ssh://github.com/sanctumsecopsmssp/cygnet-packaging',
    'source_code_uri' => 'https://github.com/sanctumsecopsmssp/cygnet-provider',
    'changelog_uri' => 'https://github.com/sanctumsecopsmssp/cygnet-provider/releases'
  }
end
