#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.2"
SHA256="1913a8e7d6094dbe6e5d38303dc1ea38d0f307693ab699e3b9cd5e8f21fb3897"
SIGNING_KEY="CDB34EB61C0A1972"
REPO="sanctumsecopsmssp/cygnet-provider"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    MINGW*|CYGWIN*|MSYS*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

install_deps_linux() {
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y cmake ninja-build build-essential libssl-dev
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y cmake ninja-build gcc openssl-devel
  else
    echo "[cygnet] No supported package manager found (need apt-get or dnf)."
    exit 1
  fi
}

verify_checksum() {
  local file="$1" actual
  if command -v sha256sum &>/dev/null; then
    actual=$(sha256sum "$file" | awk '{print $1}')
  else
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  fi
  if [ "$actual" != "$SHA256" ]; then
    echo "[cygnet] CHECKSUM MISMATCH"
    echo "[cygnet]   expected: $SHA256"
    echo "[cygnet]   actual:   $actual"
    exit 1
  fi
  echo "[cygnet] Checksum OK."
}

verify_signature() {
  local file="$1"
  if ! command -v gpg &>/dev/null; then
    echo "[cygnet] gpg not installed; skipping signature check."
    return 0
  fi
  if ! curl -fsSL "${BASE_URL}/cygnet-provider-v${VERSION}.tar.gz.asc" -o "${file}.asc"; then
    echo "[cygnet] No detached signature published; skipping."
    return 0
  fi
  gpg --keyserver keys.openpgp.org --recv-keys "$SIGNING_KEY" 2>/dev/null || true
  if gpg --verify "${file}.asc" "$file" 2>/dev/null; then
    echo "[cygnet] Signature OK."
  else
    echo "[cygnet] WARNING: signature verification failed."
  fi
}

build_and_install() {
  local tmpdir os module
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  os=$(detect_os)

  echo "[cygnet] Downloading v${VERSION}..."
  curl -fsSL "$ARCHIVE_URL" -o "${tmpdir}/cygnet.tar.gz"

  verify_checksum "${tmpdir}/cygnet.tar.gz"
  verify_signature "${tmpdir}/cygnet.tar.gz"

  echo "[cygnet] Building..."
  tar -xzf "${tmpdir}/cygnet.tar.gz" -C "${tmpdir}"
  cd "${tmpdir}/cygnet-provider-${VERSION}"
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build build

  # CMake emits .so for MODULE libraries on both Linux and macOS.
  module=$(ls build/provider/cygnetprov.so build/provider/cygnetprov.dylib 2>/dev/null | head -1)
  if [ -z "$module" ]; then
    echo "[cygnet] Build produced no provider module under build/provider."
    exit 1
  fi

  echo "[cygnet] Installing..."
  if [ "$os" = "linux" ]; then
    sudo install -Dm755 "$module" /usr/lib/cygnetprov.so
    echo "[cygnet] Installed to /usr/lib/cygnetprov.so"
    echo "[cygnet] Load with: export OPENSSL_MODULES=/usr/lib"
  else
    # OpenSSL dlopens provider modules as .dylib on Darwin.
    sudo install -Dm755 "$module" /usr/local/lib/cygnetprov.dylib
    echo "[cygnet] Installed to /usr/local/lib/cygnetprov.dylib"
    echo "[cygnet] Load with: export OPENSSL_MODULES=/usr/local/lib"
  fi

  echo "[cygnet] Verify with:"
  echo "[cygnet]   openssl list -mac-algorithms -provider cygnetprov"
}

main() {
  local os
  os=$(detect_os)
  echo "[cygnet] Detected OS: ${os}"

  case "$os" in
    linux)
      install_deps_linux
      ;;
    macos)
      echo "[cygnet] On macOS, prefer the Homebrew formula:"
      echo "[cygnet]   brew tap sanctumsecopsmssp/cygnet https://github.com/sanctumsecopsmssp/cygnet-packaging"
      echo "[cygnet]   brew trust --formula sanctumsecopsmssp/cygnet/cygnet-provider"
      echo "[cygnet]   brew install cygnet-provider"
      echo "[cygnet] Continuing with source build in 5s (Ctrl-C to abort)..."
      sleep 5
      command -v brew &>/dev/null && brew install cmake ninja openssl@3
      ;;
    windows)
      echo "[cygnet] Windows is not yet supported by this script."
      exit 1
      ;;
    *)
      echo "[cygnet] Unsupported platform: $(uname -s)"
      exit 1
      ;;
  esac

  build_and_install
}

main "$@"
