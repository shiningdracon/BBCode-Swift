import Foundation

public enum BBCodeError : Error {
    case internalError(String)
    case unfinishedOpeningTag(String)
    case unfinishedClosingTag(String)
    case unfinishedAttr(String)
    case unpairedTag(String)
    case unclosedTag(String)

    public var description: String {
        switch self {
        case .internalError(let msg):
            return msg
        case .unfinishedOpeningTag(let msg):
            return msg
        case .unfinishedClosingTag(let msg):
            return msg
        case .unfinishedAttr(let msg):
            return msg
        case .unpairedTag(let msg):
            return msg
        case .unclosedTag(let msg):
            return msg
        }
    }
}

public class BBCode {
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
        var isSelfClosing: Bool
        var allowedChildren: [BBType]? // Allowed sub-elements of this element
        var allowAttr: Bool
        var isBlock: Bool
        var render: Render?

        init(tagNeeded: Bool, isSelfClosing: Bool, allowedChildren: [BBType]?, allowAttr: Bool, isBlock: Bool, render: Render?) {
            self.tagNeeded = tagNeeded
            self.isSelfClosing = isSelfClosing
            self.allowedChildren = allowedChildren
            self.allowAttr = allowAttr
            self.isBlock = isBlock
            self.render = render
        }
    }

    enum BBType: Int {
        case unknow = 0, root
        case plain
        case br
        case paragraphStart, paragraphEnd
        case quote, code, hide, url, image, flash, user, post, topic
        case bold, italic, underline, delete, color, header
        case smilies // one to many
    }

    class TagManager {
        let tags: [TagInfo]

        init(tags: [TagInfo]) {
            var tmptags = tags



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

    var error: BBCodeError? = nil

    let tagManager: TagManager
    
    var currentParser: Parser?
    var content_parser: Parser?
    var tag_parser: Parser?
    var tag_close_parser: Parser?
    var attr_parser: Parser?
    
    var currentNode: DOMNode
    
    public init() {
        self.currentParser = Parser(parse: {_ in return nil})
        self.currentNode = DOMNode(tag: ("", .unknow, TagDescription(tagNeeded: false, isSelfClosing: false, allowedChildren: nil, allowAttr: false, isBlock: false, render: nil)), parent: nil)
        var tags: [TagInfo] = [
            ("", .plain,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { n in
                                return n.escapedValue })
            ),
            ("", .br,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { n in
                                return "<br>" })
            ),
            ("", .paragraphStart,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { n in
                                return "<p>" })
            ),
            ("", .paragraphEnd,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { n in
                                return "</p>" })
            ),
            ("quote", .quote,
             TagDescription(tagNeeded: true, isSelfClosing: false,
                            allowedChildren: [.br, .bold, .italic, .underline, .delete, .header, .color, .quote, .code, .hide, .url, .image, .flash, .user, .post, .topic, .smilies],
                            allowAttr: true,
                            isBlock: true,
                            render: { n in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<div class=\"quotebox\"><blockquote><div>"
                                } else {
                                    html = "<div class=\"quotebox\"><cite>\(n.escapedAttr)</cite><blockquote><div>"
                                }
                                html.append(n.renderChildren())
                                html.append("</div></blockquote></div>")
                                return html })
            ),
            ("code", .code,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: false, isBlock: true,
                            render: { n in
                                var html = "<div class=\"codebox\"><pre><code>"
                                html.append(n.renderChildren())
                                html.append("</code></pre></div>")
                                return html })
            ),
            ("hide", .hide,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br], allowAttr: true, isBlock: true,
                            render: nil /*TODO*/)
            ),
            ("url", .url,
             TagDescription(tagNeeded: true, isSelfClosing: false,
                            allowedChildren: [.image],
                            allowAttr: true, isBlock: false,
                            render: { n in
                                var html: String
                                var link: String
                                if n.attr.isEmpty {
                                    var isPlain = true
                                    for child in n.children {
                                        if child.type != BBType.plain {
                                            isPlain = false
                                        }
                                    }
                                    if isPlain {
                                        link = n.renderChildren()
                                        if link.isLink {
                                            html = "<a href=\"\(link)\" rel=\"nofollow\">\(link)</a>"
                                        } else {
                                            html = link
                                        }
                                    } else {
                                        html = n.renderChildren()
                                    }
                                } else {
                                    link = n.escapedAttr
                                    if link.isLink {
                                        html = "<a href=\"\(link)\" rel=\"nofollow\">\(n.renderChildren())</a>"
                                    } else {
                                        html = n.renderChildren()
                                    }
                                }
                                return html
             })
            ),
            ("img", .image,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
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
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
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
            ("post", .post,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode) in
                                var postIdStr: String
                                if n.attr.isEmpty {
                                    postIdStr = n.renderChildren()
                                    if let postId = UInt32(postIdStr) {
                                        return "<a href=\"/forum/post/\(postId)\">/forum/post/\(postId)</a>"
                                    } else {
                                        return "[post]" + postIdStr + "[/post]"
                                    }
                                } else {
                                    let text = n.renderChildren()
                                    if let postId = UInt32(n.attr) {
                                        return "<a href=\"/forum/post/\(postId)\">\(text)</a>"
                                    } else {
                                        return "[post=\(n.escapedAttr)]\(text)[/post]"
                                    }
                                }
             })
            ),
            ("topic", .topic,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode) in
                                var idStr: String
                                if n.attr.isEmpty {
                                    idStr = n.renderChildren()
                                    if let id = UInt32(idStr) {
                                        return "<a href=\"/forum/topic/\(id)\">/forum/topic/\(id)</a>"
                                    } else {
                                        return "[topic]" + idStr + "[/topic]"
                                    }
                                } else {
                                    let text = n.renderChildren()
                                    if let id = UInt32(n.attr) {
                                        return "<a href=\"/forum/topic/\(id)\">\(text)</a>"
                                    } else {
                                        return "[topic=\(n.escapedAttr)]\(text)[/topic]"
                                    }
                                }
             })
            ),
            ("b", .bold,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .italic, .delete, .underline, .url], allowAttr: false, isBlock: false,
                            render: { n in
                                var html: String = "<b>"
                                html.append(n.renderChildren())
                                html.append("</b>")
                                return html })
            ),
            ("i", .italic,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .delete, .underline, .url], allowAttr: false, isBlock: false,
                            render: { n in
                                var html: String = "<i>"
                                html.append(n.renderChildren())
                                html.append("</i>")
                                return html })
            ),
            ("u", .underline,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .delete, .url], allowAttr: false, isBlock: false,
                            render: { n in
                                var html: String = "<u>"
                                html.append(n.renderChildren())
                                html.append("</u>")
                                return html })
            ),
            ("d", .delete,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline, .url], allowAttr: false, isBlock: false,
                            render: { n in
                                var html: String = "<del>"
                                html.append(n.renderChildren())
                                html.append("</del>")
                                return html })
            ),
            ("color", .color,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline], allowAttr: true, isBlock: false,
                            render: { n in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<span style=\"color: black\">\(n.renderChildren())</span>"
                                } else {
                                    var valid = false
                                    if ["black", "green", "silver", "gray", "olive", "white", "yellow", "maroon", "navy", "red", "blue", "purple", "teal", "fuchsia", "aqua"].contains(n.attr) {
                                        valid = true
                                    } else {
                                        if n.attr.unicodeScalars.count == 4 || n.attr.unicodeScalars.count == 7 {
                                            var g = n.attr.unicodeScalars.makeIterator()
                                            if g.next() == "#" {
                                                while let c = g.next() {
                                                    if (c >= UnicodeScalar("0") && c <= UnicodeScalar("9")) || (c >= UnicodeScalar("a") && c <= UnicodeScalar("z")) || (c >= UnicodeScalar("A") && c <= UnicodeScalar("Z")) {
                                                        valid = true
                                                    } else {
                                                        valid = false
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if valid {
                                        html = "<span style=\"color: \(n.attr)\">\(n.renderChildren())</span>"
                                    } else {
                                        html = "[color=\(n.escapedAttr)]\(n.renderChildren())[/color]"
                                    }
                                }
                                return html })
            ),
            ("h", .header,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline, .delete, .url], allowAttr: false, isBlock: false,
                            render: { n in
                                var html: String = "</p><h5>"
                                html.append(n.renderChildren())
                                html.append("</h5><p>")
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
            tags.append((emote.0, .smilies, TagDescription(tagNeeded: true, isSelfClosing: true, allowedChildren: nil, allowAttr: false, isBlock: false,
                                                        render: { (n: DOMNode) in
                                                            return "<img src=\"/smilies/\(emote.1)\" alt=\"\" />" })))
        }

        // Create .root description
        let rootDescription = TagDescription(tagNeeded: false, isSelfClosing: false,
                                             allowedChildren: [],
                                             allowAttr: false, isBlock: true,
                                             render: { n in
                                                return n.renderChildren() })
        for tag in tags {
            rootDescription.allowedChildren?.append(tag.1)
        }
        tags.append(("", .root, rootDescription))

        self.tagManager = TagManager(tags: tags);
    }

    private func newDOMNode(type: BBType, parent: DOMNode?) -> DOMNode {
        if let tag = tagManager.getInfo(type: type) {
            return DOMNode(tag: tag, parent: parent)
        } else {
            return DOMNode(tag: ("", .unknow, TagDescription(tagNeeded: false, isSelfClosing: false, allowedChildren: nil, allowAttr: false, isBlock: false, render: nil)), parent: parent)
        }
    }
    
    func contentParser(g: inout USIterator) -> Parser? {
        var newNode: DOMNode = newDOMNode(type: .plain, parent: currentNode)
        currentNode.children.append(newNode)
        var lastWasCR = false
        while let c = g.next() {
            if c == UnicodeScalar(10) || c == UnicodeScalar(13) {
                if let allowedChildren = currentNode.description?.allowedChildren, allowedChildren.contains(.br) {
                    if c == UnicodeScalar(13) || (c == UnicodeScalar(10) && !lastWasCR) {
                        if newNode.value.isEmpty {
                            currentNode.children.removeLast()
                        }
                        newNode = newDOMNode(type: .br, parent: currentNode)
                        currentNode.children.append(newNode)
                        newNode = newDOMNode(type: .plain, parent: currentNode)
                        currentNode.children.append(newNode)
                    }

                    if c == UnicodeScalar(13) { // \r
                        lastWasCR = true
                    } else { // \n
                        lastWasCR = false
                    }
                } else {
                    if currentNode.type == .code {
                        newNode.value.append(Character(c))
                    } else {
                        error = BBCodeError.unclosedTag(unclosedTagDetail(unclosedNode: currentNode))
                        return nil
                    }
                }
            } else {
                lastWasCR = false

                if c == "[" { // <tag_start>
                    if currentNode.description?.allowedChildren != nil {
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
                    // illegal syntax, may be an unpaired closing tag, treat it as plain text
                    restoreNodeToPlain(node: newNode, c: c)
                    return content_parser
                }
            } else if c == "=" {
                //<opening_tag_2> ::= <tag_prefix> '=' <attr> <tag_end>
                if let tag = tagManager.getInfo(str: newNode.value) {
                    newNode.setTag(tag: tag)
                    if let allowedChildren = currentNode.description?.allowedChildren, allowedChildren.contains(newNode.type) {
                        if (newNode.description?.allowAttr)! {
                            newNode.paired = false //isSelfClosing tag has no attr, so its must be not paired
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
                    if let allowedChildren = currentNode.description?.allowedChildren, allowedChildren.contains(newNode.type) {
                        if (newNode.description?.isSelfClosing)! {
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
                // illegal syntax, treat it as plain text, and restart tag parsing from this new position
                newNode.setTag(tag: tagManager.getInfo(type: .plain)!)
                newNode.value.insert(Character(UnicodeScalar(91)), at: newNode.value.startIndex)
                return tag_parser
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

        error = BBCodeError.unfinishedOpeningTag(unclosedTagDetail(unclosedNode: currentNode))
        return nil
    }
    
    func attrParser(g: inout USIterator) -> Parser? {
        while let c = g.next() {
            if c == "]" {
                return content_parser
            } else if c == UnicodeScalar(10) || c == UnicodeScalar(13) {
                error = BBCodeError.unfinishedAttr(unclosedTagDetail(unclosedNode: currentNode))
                return nil
            } else {
                currentNode.attr.append(Character(c))
            }
        }

        //unfinished attr
        error = BBCodeError.unfinishedAttr(unclosedTagDetail(unclosedNode: currentNode))
        return nil
    }

    func tagClosingParser(g: inout USIterator) -> Parser? {
        // <tag_name> <tag_end>
        var tagName: String = ""
        while let c = g.next() {
            if c == "]" {
                if !tagName.isEmpty && tagName == currentNode.value {
                    currentNode.paired = true
                    guard let p = currentNode.parent else {
                        // should not happen
                        error = BBCodeError.internalError("bug")
                        return nil
                    }
                    currentNode = p
                    return content_parser
                } else {
                    if let allowedChildren = currentNode.description?.allowedChildren {
                        if let tag = tagManager.getInfo(str: tagName) {
                            if allowedChildren.contains(tag.1) {
                                // not paired tag
                                error = BBCodeError.unpairedTag(unclosedTagDetail(unclosedNode: currentNode))
                                return nil
                            }
                        }
                    }

                    let newNode: DOMNode = newDOMNode(type: .plain, parent: currentNode)
                    newNode.value = "[/" + tagName + "]"
                    currentNode.children.append(newNode)

                    return content_parser
                }
            } else if c == "[" {
                // illegal syntax, treat it as plain text, and restart tag parsing from this new position
                let newNode: DOMNode = newDOMNode(type: .plain, parent: currentNode)
                newNode.value = "[/" + tagName
                currentNode.children.append(newNode)
                return tag_parser
            } else if c == "=" {
                // illegal syntax, treat it as plain text
                let newNode: DOMNode = newDOMNode(type: .plain, parent: currentNode)
                newNode.value = "[/" + tagName + "="
                currentNode.children.append(newNode)
                return content_parser
            } else {
                tagName.append(Character(c))
            }
        }

        error = BBCodeError.unfinishedClosingTag(unclosedTagDetail(unclosedNode: currentNode))
        return nil
    }
    
    func restoreNodeToPlain(node: DOMNode, c: UnicodeScalar) {
        node.setTag(tag: tagManager.getInfo(type: .plain)!)
        node.value.insert(Character(UnicodeScalar(91)), at: node.value.startIndex)
        node.value.append(Character(c))
    }

    func handleNewlineAndParagraph(node: DOMNode) {
        // The end tag may be omitted if the <p> element is immediately followed by an <address>, <article>, <aside>, <blockquote>, <div>, <dl>, <fieldset>, <footer>, <form>, <h1>, <h2>, <h3>, <h4>, <h5>, <h6>, <header>, <hr>, <menu>, <nav>, <ol>, <pre>, <section>, <table>, <ul> or another <p> element, or if there is no more content in the parent element and the parent element is not an <a> element.

        // Trim head "br"s
        while node.children.first?.type == .br {
            node.children.removeFirst()
        }
        // Trim tail "br"s
        while node.children.last?.type == .br {
            node.children.removeLast()
        }

        let currentIsBlock = node.description?.isBlock ?? false
        if currentIsBlock && !(node.children.first?.description?.isBlock ?? false) && node.type != .code {
            node.children.insert(newDOMNode(type: .paragraphStart, parent: node), at: 0)
        }

        var brCount = 0
        var previous: DOMNode? = nil
        var previousOfPrevious: DOMNode? = nil
        var previousIsBlock: Bool = false
        for n in node.children {
            let isBlock = n.description?.isBlock ?? false
            if n.type == .br {
                if previousIsBlock {
                    n.setTag(tag: tagManager.getInfo(type: .plain)!)
                    previousIsBlock = false
                } else {
                    previousOfPrevious = previous
                    previous = n
                    brCount = brCount + 1
                }
            } else {
                if brCount >= 2 && currentIsBlock { // only block element can contain paragraphs
                    previousOfPrevious!.setTag(tag: tagManager.getInfo(type: .paragraphEnd)!)
                    previous!.setTag(tag: tagManager.getInfo(type: .paragraphStart)!)
                }
                brCount = 0
                previous = nil
                previousOfPrevious = nil

                handleNewlineAndParagraph(node: n)
            }

            previousIsBlock = isBlock
        }
    }

    // For unclosed tag error handling
    func unclosedTagDetail(unclosedNode: DOMNode) -> String {
        if unclosedNode.type == .root {
            // should not be here
            return ""
        }
        var text: String = "[" + unclosedNode.value + (unclosedNode.attr.isEmpty ? "]" : "=" + unclosedNode.attr + "]")
        for child in unclosedNode.children {
            text = text + nodeContext(node: child)
        }
        return text
    }

    // Called by unclosedTagDetail
    func nodeContext(node: DOMNode) -> String {
        if node.type == .root {
            // should not be here
            return ""
        } else if node.type == .plain {
            return node.value
        } else {
            if let desc = node.description, desc.isSelfClosing {
                return "[" + node.value + "]"
            } else {
                var text: String = "[" + node.value + (node.attr.isEmpty ? "]" : "=" + node.attr + "]")
                for child in node.children {
                    text = text + nodeContext(node: child)
                }
                text = text + "[/" + node.value + "]"

                return text
            }
        }
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
            throw error!
        }

        if currentNode.type != .root {
            throw BBCodeError.unclosedTag(unclosedTagDetail(unclosedNode: currentNode))
        } else {
            handleNewlineAndParagraph(node: currentNode)
            return (currentNode.description!.render!(currentNode))
        }
    }

}


extension String {
    /// Returns the String with all special HTML characters encoded.
    var stringByEncodingHTML: String {
        var ret = ""
        var g = self.unicodeScalars.makeIterator()
        while let c = g.next() {
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
            } else if c >= UnicodeScalar(0x3000 as UInt16)! && c <= UnicodeScalar(0x303F as UInt16)! {
                // CJK 标点符号 (3000-303F)
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x3400 as UInt16)! && c <= UnicodeScalar(0x4DBF as UInt16)! {
                // CJK Unified Ideographs Extension A (3400–4DBF) Rare
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x4E00 as UInt16)! && c <= UnicodeScalar(0x9FFF as UInt16)! {
                // CJK Unified Ideographs (4E00-9FFF) Common
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0xFF00 as UInt16)! && c <= UnicodeScalar(0xFFEF as UInt16)! {
                // 全角ASCII、全角中英文标点、半宽片假名、半宽平假名、半宽韩文字母 (FF00-FFEF)
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x20000 as UInt32)! && c <= UnicodeScalar(0x2A6DF as UInt32)! {
                // CJK Unified Ideographs Extension B (20000-2A6DF) Rare, historic
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x2A700 as UInt32)! && c <= UnicodeScalar(0x2B73F as UInt32)! {
                // CJK Unified Ideographs Extension C (2A700–2B73F) Rare, historic
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x2B740 as UInt32)! && c <= UnicodeScalar(0x2B81F as UInt32)! {
                // CJK Unified Ideographs Extension D (2B740–2B81F) Uncommon, some in current use
                ret.append(Character(c));
            } else if c >= UnicodeScalar(0x2B820 as UInt32)! && c <= UnicodeScalar(0x2CEAF as UInt32)! {
                // CJK Unified Ideographs Extension E (2B820–2CEAF) Rare, historic
                ret.append(Character(c));
            } else if c > UnicodeScalar(0x7E) {
                ret.append("&#\(UInt32(c));")
            } else {
                ret.append(String(Character(c)))
            }
        }
        return ret
    }

    var isLink: Bool {
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
