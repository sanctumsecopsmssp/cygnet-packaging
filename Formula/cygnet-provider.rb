class CygnetProvider < Formula
  desc "OpenSSL 3 provider for the Sanctum SecOps / Cygnus PKI stack"
  homepage "https://github.com/sanctumsecopsmssp/cygnet-provider"
  url "https://github.com/sanctumsecopsmssp/cygnet-provider/archive/refs/tags/v0.1.5.tar.gz"
  sha256 "1a613772d1bba673b176bbf031e5af814d4f29ba84676a7b47c0fe642668ec3a"
  license "Apache-2.0"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "openssl@3"

  def install
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DOPENSSL_ROOT_DIR=#{formula_opt_prefix("openssl@3")}"
    system "cmake", "--build", "build"

    # mac_forward_test skips (77) where no FIPS provider is present.
    system "ctest", "--test-dir", "build", "--output-on-failure"

    # Upstream sets the platform suffix explicitly as of 0.1.5 (.dylib on
    # Darwin); the glob remains for 0.1.4 and earlier.
    built = Dir["build/provider/cygnetprov.{dylib,so}"].first
    odie "cygnetprov module not found under build/provider" if built.nil?
    (lib/"ossl-modules").install built => "cygnetprov.dylib"

    loader = "build/tests/provider_load_test"
    (libexec/"tests").install loader if File.exist?(loader)
  end

  def caveats
    <<~EOS
      The Cygnet provider module was installed to:
        #{opt_lib}/ossl-modules/cygnetprov.dylib

      To load it, point OPENSSL_MODULES at that directory:
        export OPENSSL_MODULES="#{opt_lib}/ossl-modules"

      Verify with:
        openssl list -providers -provider cygnetprov
        openssl list -mac-algorithms -provider cygnetprov

      Note: use Homebrew's OpenSSL 3, not the system openssl.
    EOS
  end

  test do
    modules = lib/"ossl-modules"
    assert_path_exists modules/"cygnetprov.dylib"
    ENV["OPENSSL_MODULES"] = modules.to_s

    loader = libexec/"tests/provider_load_test"
    system loader if loader.exist?

    openssl = formula_opt_bin("openssl@3")/"openssl"

    providers = shell_output("#{openssl} list -providers -provider cygnetprov")
    assert_match "CygnetLib", providers
    assert_match version.to_s, providers

    macs = shell_output("#{openssl} list -mac-algorithms -provider cygnetprov")
    assert_match "CYGNET-HMAC", macs
    assert_match "CYGNET-CMAC", macs
    assert_match "CYGNET-KMAC-128", macs
    assert_match "CYGNET-KMAC-256", macs
  end
end
