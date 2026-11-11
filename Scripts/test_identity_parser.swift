import Foundation

@main struct IdentityParserChecks {
    static func main() {
        let text = """
        {{Infobox musical artist
        | name = Group
        | image = [[Wrong Person]]
        | current_members = {{plainlist|
        * [[Winter (singer)|Winter]]
        * [[Kim Min-jeong (musician)|Another Artist]]
        }}
        | past_members = * [[Former member|Former]]
        | website = [[Unrelated Person]]
        }}
        == History ==
        [[Unrelated Artist]]
        """
        let links = IdentityParser.memberLinks(in: text)
        precondition(links.contains(.init(title: "Winter (singer)", label: "Winter")))
        precondition(links.contains(.init(title: "Former member", label: "Former")))
        precondition(!links.contains { $0.title == "Unrelated Person" || $0.title == "Wrong Person" || $0.title == "Unrelated Artist" })
        precondition(IdentityParser.normalized("Jung Kook") == IdentityParser.normalized("Jungkook"))
        precondition(IdentityParser.normalized("Rosé") == "rose")
        precondition(IdentityParser.normalized("Winter (singer)") == "winter")
        precondition(IdentityParser.memberLinks(in: "No infobox or member fields").isEmpty)
        print("PASS: explicit current/past members, aliases, accented names, unrelated links excluded")
    }
}
