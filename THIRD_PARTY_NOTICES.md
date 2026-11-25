# Third-party notices

## SideInstaller by FrizzleM

Source repository: https://github.com/FrizzleM/SideInstaller  
Pinned source commit: `3ef96cef53f415a908e8dc8ead02bb0bde0f0438`  
Path: `Vendor/SideInstaller` (Git submodule)  
Full upstream licence text: [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md)

FrozenApps uses this project's pairing and signing engine as a source dependency. The upstream licence permits use/modification and distribution in source form subject to its conditions, and requires prior written authorization for certain distribution and commercial uses. The licence does not clearly grant permission to distribute a compiled FrozenApps derivative. FrozenApps CI therefore validates the build and uploads diagnostics only; obtain written permission from the upstream copyright holder before publishing a compiled IPA or using the engine commercially.

FrozenApps changes the app branding, privacy terms and primary navigation. Protocol and pairing identifiers are preserved where changing them could break compatibility. See the complete licence text linked above for the controlling terms.

## Uiverse.io components

### Neon liquid button
Source: https://uiverse.io/dexter-st/breezy-zebra-94  
Creator: dexter-st  
Licence: MIT License, Copyright (c) dexter-st  
Recreated natively in SwiftUI as `FrozenNeonLiquidButtonStyle`; the original HTML and CSS are not included.

### Curly duck radio
Source: https://uiverse.io/3bdel3ziz-T/curly-duck-62  
Creator: 3bdel3ziz-T (3bdel3zizT)  
Licence: MIT License, Copyright (c) 3bdel3ziz-T (3bdel3zizT)  
Recreated natively in SwiftUI as the SideStick workspace radio navigation; the original HTML and Tailwind markup are not included.


## React Bits — LiquidChrome background

Author: David Haz  
Project: https://github.com/DavidHDev/react-bits  
Component reference: https://reactbits.dev/backgrounds/liquid-chrome  
License: MIT + Commons Clause v1.0 (see the upstream LICENSE.md).

FrozenApps includes an app-integrated native SwiftUI/MetalKit implementation. It is distributed only as part of this application and is not offered as a standalone component, port, UI library, template or background pack. No React or JavaScript source is bundled.

## ForgeUI animation references

Author: Aman Shakya  
Project: https://github.com/AmanShakya0018/forgeui  
References: https://forgeui.in/components/animated-form, https://forgeui.in/components/animated-otp, https://forgeui.in/components/progress-stack, https://forgeui.in/components/stats-card, https://forgeui.in/components/text-reveal  
License: ForgeUI's repository license permits production-app use but prohibits redistributing the original code or derivatives as a UI library, component collection, template, starter or similar product.

The ForgeUI references will be implemented as clean-room native SwiftUI interactions. No ForgeUI React/TypeScript source is copied into FrozenApps; these interfaces remain app-integrated rather than separately distributed components.
