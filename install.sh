#!/usr/bin/env bash
# Install the Cygnet OpenSSL 3 provider module.
#
# By default this downloads the prebuilt artifact for the detected platform
# and verifies it against the release's signed SHA256SUMS manifest. Set
# CYGNET_FROM_SOURCE=1 to build from the signed source tag instead.
set -euo pipefail

VERSION="0.1.5"
REPO="sanctumsecopsmssp/cygnet-provider"
SIGNING_KEY="04F10B76199AFD0968733F70CDB34EB61C0A1972"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
FROM_SOURCE="${CYGNET_FROM_SOURCE:-0}"

log() { echo "[cygnet] $*"; }
die() { echo "[cygnet] ERROR: $*" >&2; exit 1; }

detect_platform() {
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)  echo "linux-x86_64" ;;
    Darwin/arm64)  echo "macos-arm64" ;;
    Darwin/x86_64) die "no prebuilt macOS x86_64 artifact for v${VERSION}; retry with CYGNET_FROM_SOURCE=1" ;;
    MINGW*|CYGWIN*|MSYS*) die "Windows is not supported by this script" ;;
    *) die "unsupported platform: $(uname -s)/$(uname -m)" ;;
  esac
}

artifact_name() {
  case "$1" in
    linux-x86_64) echo "cygnetprov-linux-x86_64-v${VERSION}.so" ;;
    macos-arm64)  echo "cygnetprov-macos-arm64-v${VERSION}.dylib" ;;
  esac
}

module_name() {
  case "$1" in
    linux-x86_64) echo "cygnetprov.so" ;;
    macos-arm64)  echo "cygnetprov.dylib" ;;
  esac
}

module_dir() {
  case "$1" in
    linux-x86_64)
      local triplet
      triplet=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null \
                || gcc -dumpmachine 2>/dev/null \
                || echo x86_64-linux-gnu)
      echo "/usr/lib/${triplet}/ossl-modules"
      ;;
    macos-arm64)
      if command -v brew >/dev/null 2>&1; then
        echo "$(brew --prefix)/lib/ossl-modules"
      else
        echo "/usr/local/lib/ossl-modules"
      fi
      ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# OpenSSL dlopens the module, which fails with "failed to map segment from
# shared object" on a noexec mount. Catch that before installing.
assert_execable() {
  local dir="$1"
  if command -v findmnt >/dev/null 2>&1; then
    if findmnt -T "$dir" -o OPTIONS -n 2>/dev/null | tr ',' '\n' | grep -qx noexec; then
      die "$dir is on a noexec mount; OpenSSL cannot load a provider module from there"
    fi
  fi
}

verify_manifest() {
  local dir="$1" platform="$2" artifact="$3"
  local manifest="SHA256SUMS-${platform}-v${VERSION}"
  local expected actual

  curl -fsSL "${BASE_URL}/${manifest}" -o "${dir}/${manifest}" \
    || die "could not download ${manifest}"

  expected=$(awk -v f="$artifact" '$2 == f || $2 == "*" f {print $1}' "${dir}/${manifest}")
  [ -n "$expected" ] || die "${manifest} has no entry for ${artifact}"
  actual=$(sha256_of "${dir}/${artifact}")
  [ "$expected" = "$actual" ] || die "checksum mismatch for ${artifact}: expected ${expected}, got ${actual}"
  log "checksum OK"

  if ! command -v gpg >/dev/null 2>&1; then
    log "WARNING gpg not installed; manifest signature not verified"
    return 0
  fi
  if ! curl -fsSL "${BASE_URL}/${manifest}.asc" -o "${dir}/${manifest}.asc"; then
    die "${manifest}.asc not published; refusing to install an unsigned manifest"
  fi
  gpg --list-keys "$SIGNING_KEY" >/dev/null 2>&1 \
    || gpg --keyserver hkps://keys.openpgp.org --recv-keys "$SIGNING_KEY" >/dev/null 2>&1 \
    || log "WARNING could not fetch signing key ${SIGNING_KEY}"
  gpg --verify "${dir}/${manifest}.asc" "${dir}/${manifest}" 2>/dev/null \
    || die "signature verification failed for ${manifest}"
  log "signature OK (key ${SIGNING_KEY})"
}

install_module() {
  local src="$1" platform="$2"
  local dir name
  dir=$(module_dir "$platform")
  name=$(module_name "$platform")

  assert_execable "$(dirname "$dir")"
  log "installing to ${dir}/${name}"
  sudo install -Dm755 "$src" "${dir}/${name}"

  if command -v openssl >/dev/null 2>&1; then
    if OPENSSL_MODULES="$dir" openssl list -providers -provider cygnetprov >/dev/null 2>&1; then
      log "module loads from ${dir}"
    else
      log "WARNING installed but failed to load; check the openssl version and mount options"
    fi
  fi

  log "load with: export OPENSSL_MODULES=${dir}"
  log "verify:    openssl list -mac-algorithms -provider cygnetprov"
}

install_prebuilt() {
  local platform="$1" artifact tmpdir
  artifact=$(artifact_name "$platform")
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  log "downloading ${artifact}"
  curl -fsSL "${BASE_URL}/${artifact}" -o "${tmpdir}/${artifact}" \
    || die "could not download ${artifact}"
  verify_manifest "$tmpdir" "$platform" "$artifact"
  install_module "${tmpdir}/${artifact}" "$platform"
}

install_build_deps() {
  case "$1" in
    linux-x86_64)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y cmake ninja-build build-essential libssl-dev
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y cmake ninja-build gcc openssl-devel
      else
        die "no supported package manager found (need apt-get or dnf)"
      fi
      ;;
    macos-arm64)
      command -v brew >/dev/null 2>&1 || die "Homebrew is required for a source build on macOS"
      brew install cmake ninja openssl@3
      ;;
  esac
}

install_from_source() {
  local platform="$1" workdir module
  install_build_deps "$platform"

  # Build under $HOME rather than /tmp: ctest dlopens the module, which fails
  # if TMPDIR is mounted noexec.
  workdir=$(mktemp -d "${HOME}/.cygnet-build-XXXXXX")
  trap 'rm -rf "$workdir"' EXIT

  log "downloading source for v${VERSION}"
  curl -fsSL "$ARCHIVE_URL" -o "${workdir}/cygnet.tar.gz"
  tar -xzf "${workdir}/cygnet.tar.gz" -C "$workdir"
  cd "${workdir}/cygnet-provider-${VERSION}"

  local cmake_args=(-S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release)
  if [ "$platform" = "macos-arm64" ]; then
    cmake_args+=(-DOPENSSL_ROOT_DIR="$(brew --prefix openssl@3)")
  fi
  cmake "${cmake_args[@]}"
  cmake --build build
  ctest --test-dir build --output-on-failure || die "tests failed"

  # 0.1.5 and later emit the platform-correct suffix; the glob covers older tags.
  module=$(ls build/provider/cygnetprov.dylib build/provider/cygnetprov.so 2>/dev/null | head -1)
  [ -n "$module" ] || die "build produced no provider module under build/provider"
  install_module "$module" "$platform"
}

main() {
  local platform
  platform=$(detect_platform)
  log "platform: ${platform}, version: ${VERSION}"

  if [ "$platform" = "macos-arm64" ] && [ "$FROM_SOURCE" != "1" ]; then
    log "on macOS the Homebrew formula is preferred:"
    log "  brew tap sanctumsecopsmssp/cygnet https://github.com/sanctumsecopsmssp/cygnet-packaging"
    log "  brew install cygnet-provider"
  fi

  if [ "$FROM_SOURCE" = "1" ]; then
    install_from_source "$platform"
  else
    install_prebuilt "$platform"
  fi
}

main "$@"
