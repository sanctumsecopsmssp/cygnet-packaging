# winget packaging

## Status: not shippable yet

The manifests here are structurally complete but cannot be submitted as-is.

winget supports `msi`, `exe`, `msix`, and `zip` installer types. It does not
support `.tar.gz`. The `InstallerUrl` currently points at the GitHub source
tarball, which winget will reject at validation time.

## What is required

1. A Windows CI job (`windows-latest`, MSVC, OpenSSL 3) that builds
   `cygnetprov.dll`.
2. That DLL packaged into a `.zip` (or wrapped in an `.msi`) and attached as a
   release asset.
3. `InstallerUrl` repointed at that asset, `InstallerSha256` recomputed from it,
   and `NestedInstallerFiles` / `InstallerType` set accordingly.

Until then, macOS installs via the Homebrew formula in `Formula/` and Linux
installs via `install.sh` or the `debian/` packaging.

## Superseded versions

The `0.1.1` manifest directory should be deleted. Version 0.1.1 shipped with the
four CYGNET MAC algorithms unreachable (never compiled into the module), and is
superseded by 0.1.2.
