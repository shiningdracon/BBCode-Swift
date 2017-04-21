import Foundation

public enum BBCodeError : Error {
    case syntaxError(String)
    case evaluationError(String)
    case internalError(String)
}

public class BBCode {
    /* EBNF
     <document> ::= <element> | <document> <element>
     <element> ::= <tag> | <content>
     <tag> ::= <opening_tag_1> | <opening_tag> <content> <closing_tag>
     <opening_tag> ::= <opening_tag_1> | <opening_tag_2>
     <opening_tag_1> ::= <tag_prefix> <tag_end>
     <opening_tag_2> ::= <tag_prefix> '=' <attr> <tag_end>
     <tag_prefix> ::= <tag_start> <tag_name>
     <tag_start> ::= '['
     <tag_end> ::= ']'
     <attr> ::= <character> | <attr> <character>
     <closing_tag> ::= <tag_start> '/' <tag_name> <tag_end>
     <tag_name> ::= <letter> | <tag_name> <letter>
     <content> ::= <character> | <content> <character>
     <character> ::= utf8
     <letter> ::= a-z|A-Z
     <digit> ::= 0-9
     */

    
    typealias USIterator = String.UnicodeScalarView.Iterator
    typealias Render = (DOMNode) -> String
    typealias TagInfo = (String, BBType, TagDescription)
    
    struct Parser {
        let parse: (inout USIterator) -> (Parser)?
    }

    class DOMNode {
        var children: [DOMNode] = []
        var parent: DOMNode? = nil
        private var tagType: BBType
        private var tagDescription: TagDescription? = nil
        var type: BBType {
            get {
                return tagType
            }
        }
        var description: TagDescription? {
            get {
                return tagDescription
            }
        }
        var value: String = ""
        var attr: String = ""
        var paired: Bool = true

        var escapedValue: String {
            // Only plain node value is directly usable in render, other tags needs to render subnode.
            return value.stringByEncodingHTML
        }

        var escapedAttr: String {
            return attr.stringByEncodingHTML
        }

        init(tag: TagInfo, parent: DOMNode?) {
            self.tagType = tag.1
            self.tagDescription = tag.2
            self.parent = parent
        }

        func setTag(tag: TagInfo) {
            self.tagType = tag.1
            self.tagDescription = tag.2
        }

        func renderChildren() -> String {
            var html = ""
            for n in children {
                if let render = n.description?.render {
                    html.append(render(n))
                }
            }
            return html
        }
    }

    class TagDescription {
        var tagNeeded: Bool
        var Singular: Bool
        var subelts: [BBType]? // Allowed sub-elements of this element
        var allowAttr: Bool
        var render: Render?

        init(tagNeeded: Bool, Singular: Bool, subelts: [BBType]?, allowAttr: Bool, render: Render?) {
            self.tagNeeded = tagNeeded
            self.Singular = Singular
            self.subelts = subelts
            self.allowAttr = allowAttr
            self.render = render
        }
    }

    enum BBType: Int {
        case unknow = 0, root
        case plain
        case quote, code, hide, url, image, flash, user
        case bold, italic, underline, delete, color, header
        case smilies // one to many
    }

    class TagManager {
        let tags: [TagInfo]

        init(tags: [TagInfo]) {
            var tmptags = tags

            // Create .root description
            let rootDescription = TagDescription(tagNeeded: false, Singular: false,
                                    subelts: [],
                                    allowAttr: false,
                                    render: nil)
            for tag in tags {
                rootDescription.subelts?.append(tag.1)
            }

            tmptags.append(("", .root, rootDescription))

            tmptags.sort(by: {a, b in
                if a.0.characters.count > b.0.characters.count {
                    return true
                } else {
                    return false
                }
            })
            self.tags = tmptags
        }

        func getType(str: String) -> BBType? {
            for tag in tags {
                if tag.0 == str {
                    return tag.1
                }
            }
            return nil
        }

        func getInfo(str: String) -> TagInfo? {
            for tag in tags {
                if tag.0 == str {
                    return tag
                }
            }
            return nil
        }

        func getInfo(type: BBType) -> TagInfo? {
            if type == .smilies {
                return nil
            }
            for tag in tags {
                if tag.1 == type {
                    return tag
                }
            }
            return nil
        }
    }

    var error: String? = nil

    let tagManager: TagManager
    
    var currentParser: Parser?
    var content_parser: Parser?
    var tag_parser: Parser?
    var tag_close_parser: Parser?
    var attr_parser: Parser?
    
    var currentNode: DOMNode
    
    public init() {
        self.currentParser = Parser(parse: {_ in return nil})
        self.currentNode = DOMNode(tag: ("", .unknow, TagDescription(tagNeeded: false, Singular: false, subelts: nil, allowAttr: false, render: nil)), parent: nil)
        var tags: [TagInfo] = [
            ("", .plain,
             TagDescription(tagNeeded: false, Singular: false,
                            subelts: nil,
                            allowAttr: false,
                            render: { n in
                                return n.escapedValue})
            ),
            ("quote", .quote,
             TagDescription(tagNeeded: true, Singular: false,
                            subelts: [.bold, .italic, .underline, .delete, .header, .color, .image, .url, .quote],
                            allowAttr: true,
                            render: { n in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<div class=\"quotebox\"><blockquote><div><p>"
                                } else {
                                    html = "<div class=\"quotebox\"><cite>\(n.escapedAttr)</cite><blockquote><div><p>"
                                }
                                html.append(n.renderChildren())
                                html.append("</p></div></blockquote></div>")
                                return html })
            ),
            ("code", .code,
             TagDescription(tagNeeded: true, Singular: false, subelts: nil, allowAttr: false,
                            render: { n in
                                var html = "<div class=\"codebox\"><pre><code>"
                                html.append(n.renderChildren())
                                html.append("</code></pre></div>")
                                return html })
            ),
            ("hide", .hide,
             TagDescription(tagNeeded: true, Singular: false, subelts: nil, allowAttr: true,
                            render: nil /*TODO*/)
            ),
            ("url", .url,
             TagDescription(tagNeeded: true, Singular: false, subelts: nil, allowAttr: true,
                            render: { n in
                                var html: String
                                var link: String
                                if n.attr.isEmpty {
                                    link = n.renderChildren()
                                    html = "<a href=\"\(link)\" rel=\"nofollow\">\(n.renderChildren())</a>"
                                } else {
                                    link = n.escapedAttr
                                    html = "<a href=\"\(link)\" rel=\"nofollow\">\(n.renderChildren())</a>"
                                }
                                if link.isLink {
                                    return html
                                } else {
                                    return n.renderChildren()
                                }
             })
            ),
            ("img", .image,
             TagDescription(tagNeeded: true, Singular: false, subelts: nil, allowAttr: true,
                            render: { n in
                                var html: String
                                let link: String = n.renderChildren()
                                if n.attr.isEmpty {
                                    html = "<span class=\"postimg\"><img src=\"\(link)\" alt=\"\" /></span>"
                                } else {
                                    let values = n.attr.components(separatedBy: ",").flatMap { Int($0) }
                                    if values.count == 2 && values[0] > 0 && values[0] <= 4096 && values[1] > 0 && values[1] <= 4096 {
                                        html = "<span class=\"postimg\"><img src=\"\(link)\" alt=\"\" width=\"\(values[0])\" height=\"\(values[1])\" /></span>"
                                    } else {
                                        html = "<span class=\"postimg\"><img src=\"\(link)\" alt=\"\(n.escapedAttr)\" /></span>"
                                    }
                                }
                                if link.isLink {
                                    return html
                                } else {
                                    return link
                                }
             })
            ),
            ("user", .user,
             TagDescription(tagNeeded: true, Singular: false, subelts: nil, allowAttr: true,
                            render: { (n: DOMNode) in
                                var userIdStr: String
                                if n.attr.isEmpty {
                                    userIdStr = n.renderChildren()
                                    if let userId = UInt32(userIdStr) {
                                        return "<a href=\"/forum/user/\(userId)\">/forum/user/\(userId)</a>"
                                    } else {
                                        return "[user]" + userIdStr + "[/user]"
                                    }
                                } else {
                                    let text = n.renderChildren()
                                    if let userId = UInt32(n.attr) {
                                        return "<a href=\"/forum/user/\(userId)\">\(text)</a>"
                                    } else {
                                        return "[user=\(n.escapedAttr)]\(text)[/user]"
                                    }
                                }
             })
            ),
            ("b", .bold,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.italic, .delete, .underline], allowAttr: false,
                            render: { n in
                                var html: String = "<b>"
                                html.append(n.renderChildren())
                                html.append("</b>")
                                return html })
            ),
            ("i", .italic,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.bold, .delete, .underline], allowAttr: false,
                            render: { n in
                                var html: String = "<i>"
                                html.append(n.renderChildren())
                                html.append("</i>")
                                return html })
            ),
            ("u", .underline,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.bold, .italic, .delete], allowAttr: false,
                            render: { n in
                                var html: String = "<u>"
                                html.append(n.renderChildren())
                                html.append("</u>")
                                return html })
            ),
            ("d", .delete,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.bold, .italic, .underline], allowAttr: false,
                            render: { n in
                                var html: String = "<del>"
                                html.append(n.renderChildren())
                                html.append("</del>")
                                return html })
            ),
            ("color", .color,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.bold, .italic, .underline], allowAttr: true,
                            render: { n in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<span style=\"color: black\">\(n.renderChildren())</span>"
                                } else {
                                    let validatedAttr: String = n.escapedAttr //TODO
                                    html = "<span style=\"color: \(validatedAttr)\">\(n.renderChildren())</span>"
                                }
                                return html })
            ),
            ("h", .header,
             TagDescription(tagNeeded: true, Singular: false, subelts: [.bold, .italic, .underline], allowAttr: false,
                            render: { n in
                                var html: String = "<h5>"
                                html.append(n.renderChildren())
                                html.append("</h5>")
                                return html })
            ),
            ]
        let smilies: [(String, String)] = [
            ("傻笑", "haku-simper.png"),
            ("賣萌", "haku-cute.png"),
            ("哭", "haku-cry.png"),
            ("嗝屁", "haku-die.png"),
            ("壞笑", "haku-smirk.png"),
            ("害羞", "haku-shy.png"),
            ("微笑", "haku-smile.png"),
            ("驚訝", "haku-suprise.png"),
            ("憤怒", "haku-anger.png"),
            ("暈", "haku-dizzy.png"),
            ("有愛", "haku-love.png"),
            ("汗", "haku-embarrassed.png"),
            ("流鼻血", "haku-nosebleeds.png"),
            ("漠然", "haku-indifferently.png"),
            ("生病", "haku-sick.png"),
            ("瞌睡", "haku-sleepy.png"),
            ("被炸", "haku-bombed.png"),
            ("被雷", "haku-shock.png"),
            ("裝酷", "haku-cool.png"),
            ("大笑", "haku-laugh.png"),
            ("靈感", "haku-idea.png"),
            ("疑惑", "haku-confused.png"),
            ("警惕", "haku-guard.png"),
            // Simplifyed Chinese
            ("卖萌", "haku-cute.png"),
            ("坏笑", "haku-smirk.png"),
            ("惊讶", "haku-suprise.png"),
            ("愤怒", "haku-anger.png"),
            ("晕", "haku-dizzy.png"),
            ("有爱", "haku-love.png"),
            ("灵感", "haku-idea.png"),
            ]
        for emote in smilies {
            tags.append((emote.0, .smilies, TagDescription(tagNeeded: true, Singular: true, subelts: nil, allowAttr: false,
                                                        render: { (n: DOMNode) in
                                                            return "<img src=\"/smilies/\(emote.1)\" alt=\"\" />" })))
        }
        self.tagManager = TagManager(tags: tags);
    }

    private func newDOMNode(type: BBType, parent: DOMNode?) -> DOMNode {
        if let tag = tagManager.getInfo(type: type) {
            return DOMNode(tag: tag, parent: parent)
        } else {
            return DOMNode(tag: ("", .unknow, TagDescription(tagNeeded: false, Singular: false, subelts: nil, allowAttr: false, render: nil)), parent: parent)
        }
    }
    
    func contentParser(g: inout USIterator) -> Parser? {
        let newNode: DOMNode = newDOMNode(type: .plain, parent: currentNode)
        currentNode.children.append(newNode)
        while let c = g.next() {
            if c == "[" { // <tag_start>
                if currentNode.description?.subelts != nil {
                    if newNode.value.isEmpty {
                        currentNode.children.removeLast()
                    }
                    return tag_parser
                } else if !currentNode.paired {
                    return tag_parser
                } else {
                    newNode.value.append(Character(c))
                }
            } else { // <content>
                newNode.value.append(Character(c))
            }
        }

        return nil
    }
    
    func tagParser(g: inout USIterator) -> Parser? {
        //<opening_tag> ::= <opening_tag_1> | <opening_tag_2>
        let newNode: DOMNode = newDOMNode(type: .unknow, parent: currentNode)
        currentNode.children.append(newNode)
        var index: Int = 0
        let tagNameMaxLength: Int = 8
        var isFirst: Bool = true

        while let c = g.next() {
            if isFirst && c == "/" {
                if !currentNode.paired {
                    //<closing_tag> ::= <tag_start> '/' <tag_name> <tag_end>
                    currentNode.children.removeLast()
                    return tag_close_parser
                } else {
//                    error = "unpaired closing tag"
//                    return nil
                    restoreNodeToPlain(node: newNode, c: c)
                    return content_parser
                }
            } else if c == "=" {
                //<opening_tag_2> ::= <tag_prefix> '=' <attr> <tag_end>
                if let tag = tagManager.getInfo(str: newNode.value) {
                    newNode.setTag(tag: tag)
                    if let subelts = currentNode.description?.subelts, subelts.contains(newNode.type) {
                        if (newNode.description?.allowAttr)! {
                            newNode.paired = false //singular tag has no attr, so its must be not paired
                            currentNode = newNode
                            return attr_parser
                        }
                    }
                }
                restoreNodeToPlain(node: newNode, c: c)
                return content_parser
            } else if c == "]" {
                //<tag> ::= <opening_tag_1> | <opening_tag> <content> <closing_tag>
                if let tag = tagManager.getInfo(str: newNode.value) {
                    newNode.setTag(tag: tag)
                    if let subelts = currentNode.description?.subelts, subelts.contains(newNode.type) {
                        if (newNode.description?.Singular)! {
                            //<opening_tag_1> ::= <tag_prefix> <tag_end>
                            return content_parser
                        } else {
                            //<opening_tag> <content> <closing_tag>
                            newNode.paired = false
                            currentNode = newNode
                            return content_parser
                        }
                    }
                }
                restoreNodeToPlain(node: newNode, c: c)
                return content_parser
            } else if c == "[" {
                // invalid syntax
                newNode.setTag(tag: tagManager.getInfo(type: .plain)!)
                newNode.value.insert(Character(UnicodeScalar(91)), at: newNode.value.startIndex)
                newNode.value.append(Character(c))
                return content_parser
            } else {
                if index < tagNameMaxLength {
                    newNode.value.append(Character(c))
                } else {
                    // no such tag
                    restoreNodeToPlain(node: newNode, c: c)
                    return content_parser
                }
            }
            index = index + 1
            isFirst = false
        }

        error = "unfinished opening tag"
        return nil
    }
    
    func attrParser(g: inout USIterator) -> Parser? {
        while let c = g.next() {
            if c == "]" {
                return content_parser
            } else {
                currentNode.attr.append(Character(c))
            }
        }

        //unfinished attr
        error = "unfinished attr"
        return nil
    }

    func tagClosingParser(g: inout USIterator) -> Parser? {
        var tagName: String = ""
        while let c = g.next() {
            if c == "]" {
                if !tagName.isEmpty && tagName == currentNode.value {
                    currentNode.paired = true
                    guard let p = currentNode.parent else {
                        // should not happen
                        error = "bug"
                        return nil
                    }
                    currentNode = p
                    return content_parser
                } else {
                    // not paired tag
                    error = "unparied tag"
                    return nil
                }

            } else {
                tagName.append(Character(c))
            }
        }

        //
        error = "unfinished closing tag"
        return nil
    }
    
    func restoreNodeToPlain(node: DOMNode, c: UnicodeScalar) {
        node.setTag(tag: tagManager.getInfo(type: .plain)!)
        node.value.insert(Character(UnicodeScalar(91)), at: node.value.startIndex)
        node.value.append(Character(c))
    }
    
    public func parse(bbcode: String) throws -> String {
        var g: USIterator = bbcode.unicodeScalars.makeIterator()
        self.content_parser = Parser(parse: contentParser)
        self.tag_parser = Parser(parse: tagParser)
        self.attr_parser = Parser(parse: attrParser)
        self.tag_close_parser = Parser(parse: tagClosingParser)
        error = nil
        currentParser = content_parser
        currentNode = newDOMNode(type: .root, parent: nil)

        repeat {
            currentParser = currentParser?.parse(&g)
        } while currentParser != nil

        if error != nil {
            throw BBCodeError.syntaxError(error!)
        }

        if currentNode.type != .root {
            throw BBCodeError.evaluationError("Unclosed tag")
        }

        return currentNode.renderChildren()
    }

}


extension String {
    /// Returns the String with all special HTML characters encoded.
    public var stringByEncodingHTML: String {
        var ret = ""
        var g = self.unicodeScalars.makeIterator()
        var lastWasCR = false
        while let c = g.next() {
            if c == UnicodeScalar(10) {
                if lastWasCR {
                    lastWasCR = false
                    ret.append("\n")
                } else {
                    ret.append("<br>\n")
                }
                continue
            } else if c == UnicodeScalar(13) {
                lastWasCR = true
                ret.append("<br>\r")
                continue
            }
            lastWasCR = false
            if c < UnicodeScalar(0x0009) {
                if let scale = UnicodeScalar(0x0030 + UInt32(c)) {
                    ret.append("&#x")
                    ret.append(String(Character(scale)))
                    ret.append(";")
                }
            } else if c == UnicodeScalar(0x0022) {
                ret.append("&quot;")
            } else if c == UnicodeScalar(0x0026) {
                ret.append("&amp;")
            } else if c == UnicodeScalar(0x0027) {
                ret.append("&#39;")
            } else if c == UnicodeScalar(0x003C) {
                ret.append("&lt;")
            } else if c == UnicodeScalar(0x003E) {
                ret.append("&gt;")
            } else if c > UnicodeScalar(126) {
                ret.append("&#\(UInt32(c));")
            } else {
                ret.append(String(Character(c)))
            }
        }
        return ret
    }

    public var isLink: Bool {
    #if os(Linux)
        return true //TODO
    #else
        let types: NSTextCheckingResult.CheckingType = [.link]
        let detector = try? NSDataDetector(types: types.rawValue)
        guard (detector != nil && self.characters.count > 0) else { return false }
        if detector!.numberOfMatches(in: self, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, self.characters.count)) > 0 {
            return true
        }
        return false
    #endif
    }
}
