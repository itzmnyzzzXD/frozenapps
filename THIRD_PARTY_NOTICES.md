# Third-party notices

## SideInstaller by FrizzleM

Source repository: https://github.com/FrizzleM/SideInstaller  
Pinned source commit: `3ef96cef53f415a908e8dc8ead02bb0bde0f0438`  
Path: `Vendor/SideInstaller` (Git submodule)  
Full upstream licence text: [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md)

FrozenApps uses this project's pairing and signing engine as a source dependency. The upstream licence permits use/modification and distribution in source form subject to its conditions, and requires prior written authorization for certain distribution and commercial uses. The licence does not clearly grant permission to distribute a compiled FrozenApps derivative. FrozenApps CI therefore validates the build and uploads diagnostics only; obtain written permission from the upstream copyright holder before publishing a compiled IPA or using the engine commercially.

FrozenApps changes the app branding, privacy terms and primary navigation. Protocol and pairing identifiers are preserved where changing them could break compatibility. See the complete licence text linked above for the controlling terms.


## FrozenApps vector icons

The monochrome vector icon atlas at `assets/vector-icons/icon-atlas.svg`, the AppIcon resolver and the icon importer/migration scripts are original FrozenApps project assets. They do not bundle an external icon font or runtime icon package. The generated imagesets are derived only from this checked-in local SVG atlas.
