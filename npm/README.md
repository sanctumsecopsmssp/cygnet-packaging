# @sanctumsecopsmssp/cygnet-provider

OpenSSL 3 provider module supplying the CYGNET MAC algorithms.

The binary is not bundled. On install, the package downloads the artifact for
the running platform from the `cygnet-provider` GitHub release and verifies it
against that release's `SHA256SUMS-<platform>-v<version>` manifest, checking the
detached signature when `gpg` is available. A checksum mismatch aborts the
install.

## Install

```
npm install @sanctumsecopsmssp/cygnet-provider
```

Requires an `.npmrc` pointing the scope at GitHub Packages:

```
@sanctumsecopsmssp:registry=https://npm.pkg.github.com
```

## Use

```js
const cygnet = require('@sanctumsecopsmssp/cygnet-provider');

process.env.OPENSSL_MODULES = cygnet.modulesDir();
console.log(cygnet.modulePath());
console.log(cygnet.macAlgorithms);
```

Verify with Homebrew's or the system OpenSSL 3:

```
OPENSSL_MODULES=$(node -p "require('@sanctumsecopsmssp/cygnet-provider').modulesDir()") \
  openssl list -providers -provider cygnetprov
```

## Platforms

| Platform | Artifact |
| --- | --- |
| linux x64 | `cygnetprov-linux-x86_64-v0.1.5.so` |
| macOS arm64 | `cygnetprov-macos-arm64-v0.1.5.dylib` |

Windows is not published: no `cygnetprov.dll` has been built yet. macOS x64 has
no prebuilt artifact; build from source with `CYGNET_FROM_SOURCE=1 install.sh`.

The module must live on a filesystem mounted without `noexec`, or OpenSSL fails
with `failed to map segment from shared object`.
