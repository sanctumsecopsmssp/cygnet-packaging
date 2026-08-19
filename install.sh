#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.1"
REPO="sanctumsecopsmssp/cygnet-provider"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"

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
    sudo apt-get install -y cmake build-essential libssl-dev
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y cmake gcc openssl-devel
  fi
}

build_and_install() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  echo "[cygnet] Downloading v${VERSION}..."
  curl -fsSL "${BASE_URL}/cygnet-provider-v${VERSION}.tar.gz" \
    -o "${tmpdir}/cygnet.tar.gz"

  echo "[cygnet] Verifying signature..."
  curl -fsSL "${BASE_URL}/cygnet-provider-v${VERSION}.tar.gz.asc" \
    -o "${tmpdir}/cygnet.tar.gz.asc"
  gpg --keyserver keys.openpgp.org --recv-keys CDB34EB61C0A1972 2>/dev/null || true
  gpg --verify "${tmpdir}/cygnet.tar.gz.asc" "${tmpdir}/cygnet.tar.gz" || {
    echo "[cygnet] WARNING: signature verification failed — proceeding anyway"
  }

  echo "[cygnet] Building..."
  tar -xzf "${tmpdir}/cygnet.tar.gz" -C "${tmpdir}"
  cd "${tmpdir}/cygnet-provider-${VERSION}"
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build

  echo "[cygnet] Installing..."
  OS=$(detect_os)
  if [ "$OS" = "linux" ]; then
    sudo install -Dm755 build/provider/cygnetprov.so /usr/lib/cygnetprov.so
  elif [ "$OS" = "macos" ]; then
    sudo install -Dm755 build/provider/cygnetprov.dylib /usr/local/lib/cygnetprov.dylib
  fi

  echo "[cygnet] Done. Provider installed successfully."
}

main() {
  OS=$(detect_os)
  echo "[cygnet] Detected OS: ${OS}"

  if [ "$OS" = "linux" ]; then
    install_deps_linux
  elif [ "$OS" = "macos" ]; then
    if ! command -v brew &>/dev/null; then
      echo "[cygnet] Homebrew not found. Install from https://brew.sh first."
      exit 1
    fi
    brew install cmake openssl@3
  elif [ "$OS" = "windows" ]; then
    echo "[cygnet] On Windows, use: winget install SanctumSecOps.CygnetProvider"
    exit 0
  fi

  build_and_install
}

main "$@"
