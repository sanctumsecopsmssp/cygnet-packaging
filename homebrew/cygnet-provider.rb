class CygnetProvider < Formula
  desc "OpenSSL 3 provider scaffold for Sanctum SecOps PKI stack"
  homepage "https://github.com/sanctumsecopsmssp/cygnet-provider"
  url "https://github.com/sanctumsecopsmssp/cygnet-provider/archive/refs/tags/v0.1.1.tar.gz"
  version "0.1.1"
  license "Proprietary"

  depends_on "cmake" => :build
  depends_on "openssl@3"

  def install
    system "cmake", "-S", ".", "-B", "build",
           "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}",
           "-DCMAKE_INSTALL_PREFIX=#{prefix}"
    system "cmake", "--build", "build"
    lib.install "build/provider/cygnetprov.dylib"
  end

  test do
    system "#{bin}/provider_load_test" if (bin/"provider_load_test").exist?
    assert_predicate lib/"cygnetprov.dylib", :exist?
  end
end
