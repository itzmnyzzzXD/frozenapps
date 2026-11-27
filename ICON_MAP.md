# AppIcon map

App-owned SwiftUI screens render icons through `AppIcon(name:)`. The resolver prefers an original local vector asset and uses a monochrome SF Symbol fallback when no matching vector alias exists.

| Symbol family | Vector alias |
|---|---|
| App / app badge | app |
| Refresh | refresh |
| Right arrow / external navigation | arrow-right / arrow-up |
| Check / verified / completed | check |
| Warning / exception | alert |
| Shield / lock / secure access | shield |
| File / document | file |
| Duplicate / copy | copy |
| Archive / IPA package | archive |
| Folder | folder |
| Signing / signature | signature |
| Credential key | key |
| Network / connection | network |
| iPhone / iPad | device |
| Package / box | package |
| Settings / controls | settings |
| Tools / repair | tools |
| Snowflake | snowflake |
| Sparkles / reveal | sparkles |
| Grid / catalog | grid |
| Text / logs | text |
| Trash / delete | trash |
| Activity / live engine | activity |
| Bell / alerts | bell |
| Book / guide | book |
| Checklist | checklist |
| Bolt / JIT | bolt |
| Hand / interaction | hand |
| Ellipsis / more | ellipsis |
| Filter | filter |
| Search | search |
| Pencil / edit | pencil |
| Information | info |
| Close | close |
| Add | plus |
| Chevron | chevron |
| Server | server |

Original vector source: `assets/vector-icons/icon-atlas.svg`. The local importer validates the SVG and creates individual template-rendered imagesets inside the generated asset catalogue. It performs no network access and adds no runtime package.
