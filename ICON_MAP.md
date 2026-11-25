# Icon map

## Direction

The app is native SwiftUI, so controls use one consistent iOS symbol family rather than a mixed set of downloaded bitmap icons. The login and verification surfaces use monochrome glyphs with a restrained, consistent weight; the custom app mark remains the supplied local asset.

## Flaticon reference reviewed

- [Essential UI icons set — Basic Outline](https://www.flaticon.com/packs/essential-ui-icons-set)
- Creator shown by Flaticon: **SeyfDesigner**
- Pack size: **50 icons**
- Flaticon marks free downloads as requiring author attribution.

No Flaticon SVGs are bundled in this commit. The pack was reviewed as a style reference; this avoids silently copying assets without their individual author/licence metadata into the iOS asset catalog.

## Login and verification icon map

| Purpose | Native glyph |
| --- | --- |
| App identity | Supplied `SideStickMark` asset |
| Apple account / email | `envelope` |
| Password | `lock` |
| Show / hide password | `eye` / `eye.slash` |
| Account protection | `lock.shield` |
| Device workflow | `iphone` |
| App installation | `square.and.arrow.down` |
| App library | `folder` |
| Verification options | `arrow.clockwise`, `laptopcomputer.and.iphone`, `message.fill`, `phone.fill` |

The symbols remain vector-rendered at the native UI scale and are not rasterized.
