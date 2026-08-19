fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

build number を +1 → Release でアーカイブ → TestFlight へアップロード。skip_upload:true でアップロード直前に止める

### ios release

```sh
[bundle exec] fastlane ios release
```

build number を +1 → Release でアーカイブ → App Store Connect へ binary をアップロード (metadata・screenshots は metadata_upload lane に任せる)。skip_upload:true でアップロード直前に止める

### ios metadata_upload

```sh
[bundle exec] fastlane ios metadata_upload
```



----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
