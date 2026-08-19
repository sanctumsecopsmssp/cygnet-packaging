class CygnetProvider < Formula
  desc "OpenSSL 3 provider for the Sanctum SecOps / Cygnus PKI stack"
  homepage "https://github.com/sanctumsecopsmssp/cygnet-provider"
  url "https://github.com/sanctumsecopsmssp/cygnet-provider/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "2090ec96e7bdcc351211da9e754b394c8392e7d5033cda4c57aeacd8eabb4b63"
  license "Apache-2.0"
  version "0.1.1"

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
    EOS
  end

  test do
    assert_predicate lib/"cygnetprov.dylib", :exist?
    ENV["OPENSSL_MODULES"] = lib
    loader = libexec/"tests/provider_load_test"
    system loader if loader.exist?
  end
end
