![](Documentation/83d6cfcf-f707-4ce8-b374-c748b64ccc81-md.jpeg)

<!--
GitHub Topics:
swift, swiftpm, spm-plugin, localization, xcstrings, ios, macos, xcode, codegen
-->

<p align="center">
  <strong>Structured Strings Catalog Generator</strong><br/>
  Type-safe localization for modern Swift projects.
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/Swift-5.9+-orange" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Platforms-iOS%20|%20macOS-blue" /></a>
  <a href="#"><img src="https://img.shields.io/badge/SPM-Plugin-green" /></a>
  <a href="#"><img src="https://img.shields.io/badge/License-MIT-lightgrey" /></a>
</p>

## Why

A focused Swift Package Manager plugin that generates a structured, strongly‑typed interface for your Strings Catalog (.xcstrings). This is a pragmatic, Apple‑quality solution you can use today when popular tools (like SwiftGen) can’t fully support your current strings catalog workflow. It’s working, production‑friendly — but not yet a complete replacement for every edge case.

Motivation: We love SwiftGen, but for modern Strings Catalogs and certain dynamic bundle layouts, it can’t deliver exactly what we need. This plugin fills that gap by generating a clean, namespaced Swift API from your .xcstrings, ready to use in app and package targets.

Strings Catalogs are Apple’s present and future.  
Swift’s type system is merciless.  
Manually wiring localization keys is a tax nobody should pay twice.

This **Swift Package Manager plugin** generates a **structured, namespaced, type-safe Swift API** directly from your `.xcstrings`.

✅ No scripts.  
✅ No runtime magic.  
✅ No guessing how plurals or placeholders behave.

If it builds, it localizes.

---

## What You Get

- Deterministic, CI-friendly code generation
- Namespaced APIs instead of raw string keys
- Compile-time checked formatting arguments
- Plural rules driven by the catalog itself
- A single translation entry point you control
- Works in app targets and Swift packages
- Compatible with UIKit and SwiftUI

Focused scope. Boring output. Predictable behavior.

---

## Configuration

Place a configuration file named `StringsCatalogPluginConfig.json` at the root of your package (same directory as `Package.swift`). The plugin discovers this file automatically during `swift build` and in Xcode builds.

### Minimal example

```json
{
    "input": "Resources/App.xcstrings",
    "outputDir": "Generated",
    "output": "L10n.swift",
    "table": "App",
    "name": "L10n",
    "access": "internal",
    "locale": "en",
    "separator": "_"
}
```
---

## Example

Given a catalog entry like:

```
profile.title
```

Generated API:

```swift
Strings.Profile.title
```

With parameters:

```swift
Strings.Profile.greeting(name: "Gábor")
```

Plural forms stay honest:

```swift
Strings.Cart.items(count: 3)
```

If you pass the wrong argument type, the compiler complains before your users do.

---

## Supported Formatting

Fully typed `printf`-style placeholders, including:

`%@` ` %d ` `%f` `%u` `%ld` `%lld` `%x/%X` `%o` `%c` `%e/%E` `%g/%G`

If your catalog allows it, the generator respects it.

---

## Installation

Add the dependency:

```swift
.package(
    url: "https://github.com/your-org/strings-catalog-plugin.git",
    from: "1.0.0"
)
```

Attach the plugin to the target owning the `.xcstrings` file:

```swift
.target(
    name: "AppCore",
    plugins: [
        .plugin(
            name: "StringsCatalogPlugin",
            package: "strings-catalog-plugin"
        )
    ]
)
```

Run a build. Generated code appears. No extra steps.

---

## Design Constraints

This project is intentionally opinionated:

- Explicit over clever
- Compile-time errors over runtime surprises
- Generated code should be boring
- If Xcode supports it, the plugin should too

It is not a drop-in replacement for legacy `.strings` pipelines.
It is built for modern projects using Strings Catalogs correctly.

---

## Hacker News Compatibility Statement

- No YAML
- No hidden build steps
- No runtime reflection
- No global state
- No code generation during app launch

Just SwiftPM doing what SwiftPM was designed to do.

---

## Status

Actively used. Stable surface. Small footprint.  
Expect incremental improvements, not churn.

---

## License

MIT.  
Fork it. Ship it. Improve it.  
Please don’t turn it into a framework.
