import Foundation

// Restricted to explicit current/past member fields, never arbitrary article links.
nonisolated enum IdentityParser {
    struct Link: Equatable { let title: String; let label: String }
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
    }
    static func memberLinks(in text: String) -> [Link] {
        guard let fields = try? NSRegularExpression(pattern: "(?ms)^\\|[ \\t]*(?:current_members|past_members|members)[ \\t]*=[ \\t]*(.*?)(?=^\\|[ \\t]*\\w+[ \\t]*=|^\\}\\}|\\z)"),
              let links = try? NSRegularExpression(pattern: "\\[\\[([^\\]|#]+)(?:\\|([^\\]]+))?\\]\\]") else { return [] }
        let source = text as NSString
        return fields.matches(in: text, range: NSRange(location: 0, length: source.length)).flatMap { field in
            let content = source.substring(with: field.range(at: 1)) as NSString
            return links.matches(in: content as String, range: NSRange(location: 0, length: content.length)).compactMap { link -> Link? in
                let title = content.substring(with: link.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.contains(":"), !title.isEmpty else { return nil }
                let label = link.range(at: 2).location == NSNotFound ? title : content.substring(with: link.range(at: 2))
                return Link(title: title, label: label)
            }
        }
    }
}
