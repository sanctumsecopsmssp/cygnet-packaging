# cygnet-packaging

Cross-platform packaging for [Cygnet Provider](https://github.com/sanctumsecopsmssp/cygnet-provider),
an OpenSSL 3 provider maintained by Sanctum SecOps LLC.

Current version: **0.1.2**

## macOS (Homebrew)

Three commands. The `brew trust` step is required — since Homebrew 6.0.0,
third-party taps are not loaded until explicitly trusted.

```sh
brew tap sanctumsecopsmssp/cygnet https://github.com/sanctumsecopsmssp/cygnet-packaging
brew trust --formula sanctumsecopsmssp/cygnet/cygnet-provider
brew install cygnet-provider
```

The explicit tap URL is required because this repository is not named
`homebrew-cygnet`.

## Linux

```sh
curl -fsSL https://raw.githubusercontent.com/sanctumsecopsmssp/cygnet-packaging/main/install.sh | bash
```

The script installs build dependencies, verifies the release checksum and GPG
signature, builds from source, and installs the module to `/usr/lib`.

Debian packaging lives in `debian/` for sites that prefer a `.deb`.

## Windows

Not yet supported. See `winget/README.md` — the manifests exist but require a
prebuilt `cygnetprov.dll` published as a zip or msi asset before they can be
submitted.

## Verifying the install

Use OpenSSL 3, not the system `openssl` (macOS ships LibreSSL, which has no
provider support):

```sh
export OPENSSL_MODULES="$(brew --prefix cygnet-provider)/lib"   # macOS
export OPENSSL_MODULES=/usr/lib                                 # Linux

openssl list -providers -provider cygnetprov
openssl list -mac-algorithms -provider cygnetprov
```

Expected:

```
Provided MACs:
  CYGNET-HMAC @ cygnetprov
  CYGNET-CMAC @ cygnetprov
  CYGNET-KMAC-128 @ cygnetprov
  CYGNET-KMAC-256 @ cygnetprov
```

KEM, signature, and key-manager lists are empty by design; those remain
integration boundaries in the provider scaffold.

## Verifying release provenance

```sh
gpg --keyserver keys.openpgp.org --recv-keys CDB34EB61C0A1972
git verify-tag v0.1.2
gpg --verify cygnet-provider-v0.1.2.tar.gz.asc cygnet-provider-v0.1.2.tar.gz
```

## Do not use 0.1.1

Release 0.1.1 advertised four MAC algorithms that were unreachable in the
shipped module: the implementation was never compiled into the build. Use 0.1.2
or later.

## Support

support@sanctumsecops.com
