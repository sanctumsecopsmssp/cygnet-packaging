# frozen_string_literal: true

# Locates the Cygnet OpenSSL 3 provider module installed by the gem's extension
# step, so callers never hardcode the path or the platform suffix.
module CygnetProvider
  VERSION = '0.1.5'
  PROVIDER_NAME = 'cygnetprov'

  MAC_ALGORITHMS = %w[
    CYGNET-HMAC
    CYGNET-CMAC
    CYGNET-KMAC-128
    CYGNET-KMAC-256
  ].freeze

  class ModuleMissing < StandardError; end

  def self.modules_dir
    File.expand_path('cygnet_provider/ossl-modules', __dir__)
  end

  def self.module_file_name
    # OpenSSL dlopens provider modules as .dylib on Darwin, .so elsewhere.
    RUBY_PLATFORM.include?('darwin') ? 'cygnetprov.dylib' : 'cygnetprov.so'
  end

  def self.module_path
    path = File.join(modules_dir, module_file_name)
    unless File.exist?(path)
      raise ModuleMissing, "Cygnet provider module not found at #{path}; reinstall the gem"
    end

    path
  end

  # Convenience for shelling out to openssl with the module discoverable.
  def self.env
    { 'OPENSSL_MODULES' => modules_dir }
  end
end
