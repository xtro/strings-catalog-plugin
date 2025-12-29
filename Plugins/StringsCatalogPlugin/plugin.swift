import PackagePlugin
import Foundation

@main
struct StringsCatalogPlugin: BuildToolPlugin {
    struct Config {
        var input: Path
        var outputDir: Path
        var outputFileName: String
        var table: String
        var typeName: String
        var access: String
        var localeForComments: String
        var separator: String

        var outputFile: Path { outputDir.appending(outputFileName) }
    }

    private func loadConfig(context: PluginContext) -> Config {
        // Defaults
        var input = context.package.directory.appending("localization.xcstrings")
        var outputDir = context.pluginWorkDirectory.appending("Generated")
        var outputFileName = "L10n.swift"
        var table = "localization"
        var typeName = "L10n"
        var access = "public"
        var localeForComments = "en"
        var separator = "_"

        // Optional JSON config at package root: StringsCatalogPluginConfig.json
        let configPath = context.package.directory.appending("StringsCatalogPluginConfig.json")
        if FileManager.default.fileExists(atPath: configPath.string) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: configPath.string))
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let v = json["input"] as? String {
                        input = Path(v.hasPrefix("/") ? v : context.package.directory.appending(v).string)
                    }
                    if let v = json["outputDir"] as? String {
                        outputDir = Path(v.hasPrefix("/") ? v : context.pluginWorkDirectory.appending(v).string)
                    }
                    if let v = json["output"] as? String { outputFileName = v }
                    if let v = json["table"] as? String { table = v }
                    if let v = json["name"] as? String { typeName = v }
                    if let v = json["typeName"] as? String { typeName = v }
                    if let v = json["access"] as? String { access = v }
                    if let v = json["locale"] as? String { localeForComments = v }
                    if let v = json["commentsLocale"] as? String { localeForComments = v }
                    if let v = json["separator"] as? String { separator = v }
                }
            } catch {
                Diagnostics.warning("Failed to read StringsCatalogPluginConfig.json: \(error.localizedDescription)")
            }
        }

        return Config(input: input,
                      outputDir: outputDir,
                      outputFileName: outputFileName,
                      table: table,
                      typeName: typeName,
                      access: access,
                      localeForComments: localeForComments,
                      separator: separator)
    }

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Parse plugin arguments (from Package.swift plugin usage)
        let config = loadConfig(context: context)

        // Prepare paths
        let outputDir = config.outputDir
        let output = config.outputFile
        let input = config.input

        // Generate content now (inside plugin) and write to a temp file under pluginWorkDirectory
        let temp = context.pluginWorkDirectory.appending("temp-\(config.outputFileName)")
        do {
            let content = try generateContent(inputPath: input.string,
                                              table: config.table,
                                              typeName: config.typeName,
                                              access: config.access,
                                              locale: config.localeForComments,
                                              separator: config.separator)
            try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
            try content.write(toFile: temp.string, atomically: true, encoding: .utf8)
        } catch {
            Diagnostics.error("StringsCatalogPlugin failed to generate content: \(error.localizedDescription)")
        }

        // Prebuild command: copy temp to output directory so SwiftPM tracks it as generated
        return [
            .prebuildCommand(
                displayName: "Generate \(config.outputFileName) from xcstrings",
                executable: Path("/bin/cp"),
                arguments: [temp, output],
                outputFilesDirectory: outputDir
            )
        ]
    }
    private func generateContent(inputPath: String, table: String, typeName: String, access: String, locale: String, separator: String) throws -> String {
        let url = URL(fileURLWithPath: inputPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "StringsCatalogPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input xcstrings not found at \(url.path)"])
        }
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            throw NSError(domain: "StringsCatalogPlugin", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid xcstrings JSON structure"])
        }

        var keys: [String] = []
        var commentsByKey: [String: String] = [:]
        var pluralKeys: Set<String> = []

        for (key, value) in strings {
            keys.append(key)
            if let entry = value as? [String: Any],
               let localizations = entry["localizations"] as? [String: Any] {
                // Collect a comment from the preferred locale if available
                if let locDict = localizations[locale] as? [String: Any],
                   let stringUnit = locDict["stringUnit"] as? [String: Any],
                   let commentValue = stringUnit["value"] as? String {
                    commentsByKey[key] = commentValue
                }

                // Detect plural: any localization that has variations.plural
                for (_, rawLoc) in localizations {
                    if let loc = rawLoc as? [String: Any],
                       let variations = loc["variations"] as? [String: Any],
                       variations["plural"] != nil {
                        pluralKeys.insert(key)
                        break
                    }
                }
            }
        }

        keys.sort()
        let generator = StructuredGenerator(tableName: table)
        return generator.generate(
            name: typeName,
            table: table,
            keys: keys,
            pluralKeys: pluralKeys,
            commentsByKey: commentsByKey,
            separator: separator,
            access: access
        )
    }
}

