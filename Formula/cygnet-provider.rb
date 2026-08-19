class CygnetProvider < Formula
  desc "OpenSSL 3 provider for the Sanctum SecOps / Cygnus PKI stack"
  homepage "https://github.com/sanctumsecopsmssp/cygnet-provider"
  url "https://github.com/sanctumsecopsmssp/cygnet-provider/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "1913a8e7d6094dbe6e5d38303dc1ea38d0f307693ab699e3b9cd5e8f21fb3897"
  license "Apache-2.0"
  version "0.1.2"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "openssl@3"

  def install
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}"
    system "cmake", "--build", "build"

    # CMake gives MODULE libraries a .so suffix on macOS, not .dylib, so accept
    # either. OpenSSL expects provider modules to end in .dylib on Darwin.
    built = Dir["build/provider/cygnetprov.{dylib,so}"].first
    odie "cygnetprov module not found under build/provider" if built.nil?
    lib.install built => "cygnetprov.dylib"

    loader = "build/tests/provider_load_test"
    (libexec/"tests").install loader if File.exist?(loader)
  end

  def caveats
    <<~EOS
      The Cygnet provider module was installed to:
        #{lib}/cygnetprov.dylib

      To load it, point OPENSSL_MODULES at that directory:
        export OPENSSL_MODULES="#{lib}"

      Verify with:
        openssl list -providers -provider cygnetprov
        openssl list -mac-algorithms -provider cygnetprov

      Note: use Homebrew's OpenSSL 3, not the system openssl.
    EOS
  end

  test do
    assert_predicate lib/"cygnetprov.dylib", :exist?
    ENV["OPENSSL_MODULES"] = lib

    loader = libexec/"tests/provider_load_test"
    system loader if loader.exist?

    openssl = Formula["openssl@3"].opt_bin/"openssl"
    macs = shell_output("#{openssl} list -mac-algorithms -provider cygnetprov")
    assert_match "CYGNET-HMAC", macs
    assert_match "CYGNET-CMAC", macs
    assert_match "CYGNET-KMAC-128", macs
    assert_match "CYGNET-KMAC-256", macs
  end
end
