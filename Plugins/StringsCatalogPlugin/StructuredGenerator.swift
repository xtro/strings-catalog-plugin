import Foundation

public final class StructuredGenerator {
    private let tableName: String
    
    public init(tableName: String) {
        self.tableName = tableName
    }
    
    public func generate(name: String, table: String, keys: [String], pluralKeys: Set<String> = [], commentsByKey: [String: String] = [:], separator: String, access: String) -> String {
        // Build the tree
        let root = Node(separator: separator)
        for key in keys {
            root.insert(key: key)
        }
        
        var output = """
        // Generated using StringsCatalogPlugin

        import Foundation
        
        fileprivate let tableName: String = \"\(table)\"
        \(access) enum \(name) {

        """
        output += render(node: root, level: 1, prefix: [], commentsByKey: commentsByKey, separator: separator, access: access, table: table, pluralKeys: pluralKeys)
        
        output += """
        }
        
        fileprivate extension String {
            func camelCased(with separator: Character) -> String {
                return lowercased()
                    .split(separator: separator)
                    .enumerated()
                    .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
                    .joined()
            }
        }
        
        fileprivate func translate(base: String, _ key: String) -> String? {
            let localizableKey = "\\(base)\(separator)\\(key.camelCased(with: "\(separator)"))"
            let localizedKey = translate(localizableKey)
            if localizedKey == localizableKey {
                return nil
            }
            return localizedKey
        }
        
        fileprivate func translate(_ key: String, _ args: CVarArg...) -> String {
            let format = key.localize(withTable:)(tableName)
            return String(format: format, arguments: args)
        }
        
        fileprivate extension String {
            func localize(withTable tableName: String = "") -> String {
                NSLocalizedString(self, tableName: tableName, value: self, comment: "")
            }
        }

        """
        
        return output
    }
    
    private func typeName(from s: String, separator: String) -> String {
        let raw = s
        let parts = raw.split(separator: separator).map(String.init)
        var joined = parts.map { seg -> String in
            guard let first = seg.first else { return seg }
            let rest = seg.dropFirst()
            return String(first).uppercased() + rest
        }.joined()
        if let first = joined.first, !(first.isLetter || first == Character(separator)) {
            joined = separator + joined
        }
        return escapeIfKeywordOrInvalidIdentifier(joined)
    }
    
    private func sanitizeLeaf(_ s: String, separator: String) -> String {
        // lowerCamelCase without extra splitting; ensure valid identifier
        var result = s
        // keep as-is (already lowerCamel in keys), but replace invalid chars
        result = String(result.map { ($0.isLetter || $0.isNumber) ? $0 : Character(separator) })
        if let f = result.first, f.isNumber { result = separator + result }
        return escapeIfKeywordOrInvalidIdentifier(result)
    }
    
    private func escapeIfKeywordOrInvalidIdentifier(_ name: String) -> String {
        // Backtick Swift keywords and ensure valid leading character
        let swiftKeywords: Set<String> = [
            "associatedtype","class","deinit","enum","extension","fileprivate","func","import","init","inout","internal","let","open","operator","private","precedencegroup","protocol","public","rethrows","static","struct","subscript","typealias","var","break","case","continue","default","defer","do","else","fallthrough","for","guard","if","in","repeat","return","switch","where","while","as","Any","catch","false","is","nil","super","self","Self","throw","throws","true","try","_","__COLUMN__","__FILE__","__FUNCTION__","__LINE__" 
        ]
        var result = name
        if swiftKeywords.contains(result) {
            return "`" + result + "`"
        }
        return result
    }
    
    private enum PlaceholderType {
        case int
        case float
        case string
    }

    private func parsePlaceholders(for key: String, comment: String?, pluralKeys: Set<String>) -> [PlaceholderType] {
        let text = (comment ?? "")
        // Detect explicit placeholders in the comment text
        let patterns: [(regex: String, type: PlaceholderType)] = [
            // Strings
            ("%\\d+\\$@", .string), ("%@", .string),
            // Integers
            ("%\\d+\\$d", .int), ("%d", .int),
            ("%\\d+\\$u", .int), ("%u", .int),
            ("%\\d+\\$ld", .int), ("%ld", .int),
            ("%\\d+\\$lld", .int), ("%lld", .int),
            ("%\\d+\\$x", .int), ("%x", .int),
            ("%\\d+\\$X", .int), ("%X", .int),
            ("%\\d+\\$lx", .int), ("%lx", .int),
            ("%\\d+\\$lX", .int), ("%lX", .int),
            ("%\\d+\\$o", .int), ("%o", .int),
            ("%\\d+\\$c", .int), ("%c", .int),
            // Floats / scientific / general
            ("%\\d+\\$f", .float), ("%f", .float),
            ("%\\d+\\$e", .float), ("%e", .float),
            ("%\\d+\\$E", .float), ("%E", .float),
            ("%\\d+\\$g", .float), ("%g", .float),
            ("%\\d+\\$G", .float), ("%G", .float)
        ]
        var found: [PlaceholderType] = []
        for (pattern, t) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
                for _ in matches { found.append(t) }
            }
        }

        // Plural detection: rely solely on explicit info from Strings Catalog via `pluralKeys`
        let explicitPlural = pluralKeys.contains(key)
        let isPlural = explicitPlural

        if isPlural {
            // Ensure at least one Int parameter for the count selector
            if !found.contains(where: { if case .int = $0 { return true } else { return false } }) {
                found.insert(.int, at: 0)
            }
        }

        return found
    }

    private func functionSignature(for name: String, placeholders: [PlaceholderType], access: String) -> (signature: String, callArgs: String) {
        guard !placeholders.isEmpty else {
            return ("\(access) static var \(name): String", "")
        }
        var params: [String] = []
        var callArgs: [String] = []
        for (idx, ph) in placeholders.enumerated() {
            let p = "p\(idx+1)"
            switch ph {
            case .int:
                params.append("_ \(p): Int")
                callArgs.append(p)
            case .float:
                params.append("_ \(p): Double")
                callArgs.append(p)
            case .string:
                params.append("_ \(p): Any")
                callArgs.append("String(describing: \(p))")
            }
        }
        let sig = "\(access) static func \(name)(\(params.joined(separator: ", "))) -> String"
        return (sig, callArgs.joined(separator: ", "))
    }

    private func docComment(_ text: String, indent: String) -> String {
        return text
            .split(whereSeparator: \.isNewline)
            .map { "\(indent)/// \($0)" }
            .joined(separator: "\n") + "\n"
    }
    
    private func render(node: Node, level: Int, prefix: [String] = [], commentsByKey: [String: String], separator: String, access: String, table: String, pluralKeys: Set<String>) -> String {
        var out = ""
        let indent = String(repeating: "    ", count: level)

        // Emit child enums
        for (name, child) in node.children.sorted(by: { $0.key < $1.key }) {
            // If the child has no children and no leaves, skip
            if child.children.isEmpty && child.leaves.isEmpty { continue }

            let enumName = typeName(from: name, separator: separator)
            let childPrefix = prefix + [name]
            out += "\(indent)\(access) enum \(enumName) {\n"

            // Emit leaves inside child scope with disambiguation
            var usedNames = Set<String>()
            for leaf in child.leaves.sorted(by: { $0.name < $1.name }) {
                let key = leaf.fullKey
                
                let cmt = commentsByKey[key]
                let placeholders = parsePlaceholders(for: key, comment: cmt, pluralKeys: pluralKeys)
                let isPlural = pluralKeys.contains(key)
                
                var prop = sanitizeLeaf(leaf.name, separator: separator)
                if usedNames.contains(prop) {
                    // Disambiguate using previous segment
                    let parts = key.split(separator: separator).map(String.init)
                    if let prev = parts.dropLast().last {
                        let prevId = sanitizeLeaf(prev, separator: separator)
                        let cap = prop.prefix(1).uppercased() + prop.dropFirst()
                        prop = prevId + cap
                    }
                }
                usedNames.insert(prop)
                prop = escapeIfKeywordOrInvalidIdentifier(prop)

                if let hu = cmt, !hu.isEmpty {
                    out += docComment(hu, indent: indent + "    ")
                } else if isPlural {
                    out += "\(indent)    /// Plural format key: \(key)\n"
                } else {
                    out += "\(indent)    /// key: \(key)\n"
                }
                
                let sig = functionSignature(for: prop, placeholders: placeholders, access: access)
                if placeholders.isEmpty {
                    out += "\(indent)    \(sig.signature) { translate(\"\(key)\") }\n"
                } else {
                    out += "\(indent)    \(sig.signature) { translate(\"\(key)\"\(sig.callArgs.isEmpty ? "" : ", \(sig.callArgs)")) }\n"
                }
            }
            
            

            // Dynamic get for this scope if it has children or leaves
            if !child.children.isEmpty || !child.leaves.isEmpty {
                let base = childPrefix.joined(separator: separator)
                out += "\(indent)    \(access) static func get(_ key: String) -> String? { translate(base: \"\(base)\", key) }\n"
            }

            // Recurse deeper
            if !child.children.isEmpty {
                out += render(node: child, level: level + 1, prefix: childPrefix, commentsByKey: commentsByKey, separator: separator, access: access, table: table, pluralKeys: pluralKeys)
            }

            out += "\(indent)}\n"
        }

        return out
    }
    
    private class Node {
        internal init(separator: String) {
            self.separator = separator
        }
        let separator: String
        var children: [String: Node] = [:]
        var leaves: [(name: String, fullKey: String)] = []
        
        func insert(key: String) {
            let parts = key.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
            insert(parts: parts, fullKey: key)
        }
        
        private func insert(parts: [String], fullKey: String) {
            if parts.isEmpty {
                return
            } else {
                let first = parts[0]
                let rest = Array(parts.dropFirst())
                if rest.isEmpty {
                    // last segment becomes a leaf on current node
                    leaves.append((name: first, fullKey: fullKey))
                } else {
                    if children[first] == nil {
                        children[first] = Node(separator: separator)
                    }
                    children[first]!.insert(parts: rest, fullKey: fullKey)
                }
            }
        }
    }
}

