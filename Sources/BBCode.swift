import Foundation

public enum BBCodeError: Error {
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

//typealias USIterator = String.UnicodeScalarView.Iterator
typealias Render = (DOMNode, [String: Any]?) -> String
typealias TagInfo = (String, BBType, TagDescription)

class USIterator {
    private var startPtr: UnsafeMutablePointer<UInt8>
    private var endPtr: UnsafeMutablePointer<UInt8>
    private var curPtr: UnsafeMutablePointer<UInt8>

    init(start: UnsafeMutablePointer<UInt8>, length: Int) {
        startPtr = start
        endPtr = start + length
        curPtr = start - 1
    }

    func next() -> UInt8? {
        if curPtr < endPtr - 1 {
            curPtr = curPtr + 1
            return (curPtr).pointee
        } else {
            return nil
        }
    }

    func currentPointer() -> UnsafeMutablePointer<UInt8> {
        return curPtr
    }
}

struct Parser {
    let parse: (inout USIterator, Worker) -> (Parser)?
}

class Worker {
    let tagManager: TagManager
    var currentNode: DOMNode
    var error: BBCodeError?
    private let rootNode: DOMNode

    init(tagManager: TagManager) {
        self.tagManager = tagManager
        self.rootNode = newDOMNode(type: .root, parent: nil, tagManager: tagManager)

        self.currentNode = self.rootNode
        self.error = nil
    }

    func parse(_ bbcode: String) -> DOMNode? {
        var data = bbcode.data(using: String.Encoding.utf8)!
        data.withUnsafeMutableBytes({ (ptr: UnsafeMutablePointer<UInt8>) -> Void in
            var g: USIterator = USIterator(start: ptr, length: data.count)
            var currentParser: Parser? = content_parser
            repeat {
                currentParser = currentParser?.parse(&g, self)
            } while currentParser != nil
        })

        if error == nil {
            if currentNode.type == .root {
                return currentNode
            }
        }

        return nil
    }
}

class BBString {
    var startPtr: UnsafeMutablePointer<UInt8>?
    var endPtr: UnsafeMutablePointer<UInt8>?

    init () {
        startPtr = nil
        endPtr = nil
    }

//    init(start: UnsafeMutablePointer<UInt8>) {
//        startPtr = start
//        endPtr = start
//    }

//    func setStart(_ start: UnsafeMutablePointer<UInt8>) {
//        startPtr = start
//        endPtr = start
//    }

    func append(current: UnsafeMutablePointer<UInt8>, count: Int = 1) {
        if startPtr == nil {
            startPtr = current
            endPtr = current
        }
        endPtr = endPtr! + count
    }

    func prepend(current: UnsafeMutablePointer<UInt8>, count: Int = 1) {
        if startPtr == nil {
            startPtr = current
            endPtr = current
        }
        startPtr = startPtr! - count
    }

    func toString() -> String {
        if self.isEmpty {
            return ""
        } else {
            return String(bytesNoCopy: startPtr!, length: endPtr! - startPtr!, encoding: String.Encoding.utf8, freeWhenDone: false)!
        }
    }

    var stringByEncodingHTML: String {
        if self.isEmpty {
            return ""
        } else {
            return String(bytesNoCopy: startPtr!, length: endPtr! - startPtr!, encoding: String.Encoding.utf8, freeWhenDone: false)!.stringByEncodingHTML
        }
    }

    var isEmpty: Bool {
        return startPtr == nil || endPtr == startPtr
    }

    var count: Int {
        if startPtr != nil {
            return endPtr! - startPtr!
        } else {
            return 0
        }
    }

    static func == (lhs: BBString, rhs: BBString) -> Bool {
        if lhs.startPtr != nil {
            if lhs.count == rhs.count {
                for i in (0..<lhs.count) {
                    if (lhs.startPtr! + i).pointee != (rhs.startPtr! + i).pointee {
                        return false
                    }
                }
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

class DOMNode {
    var children: [DOMNode] = []
    weak var parent: DOMNode? = nil
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
    var value: BBString
    var attr: BBString
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
        self.value = BBString()
        self.attr = BBString()
    }

    func setTag(tag: TagInfo) {
        self.tagType = tag.1
        self.tagDescription = tag.2
    }

    func renderChildren(_ args: [String: Any]?) -> String {
        var html = ""
        for n in children {
            if let render = n.description?.render {
                html.append(render(n, args))
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
    case quote, code, hide, url, image, video, flash, user, post, topic
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

func newDOMNode(type: BBType, parent: DOMNode?, tagManager: TagManager) -> DOMNode {
    if let tag = tagManager.getInfo(type: type) {
        return DOMNode(tag: tag, parent: parent)
    } else {
        return DOMNode(tag: ("", .unknow, TagDescription(tagNeeded: false, isSelfClosing: false, allowedChildren: nil, allowAttr: false, isBlock: false, render: nil)), parent: parent)
    }
}

func contentParser(g: inout USIterator, worker: Worker) -> Parser? {
    var newNode: DOMNode = newDOMNode(type: .plain, parent: worker.currentNode, tagManager: worker.tagManager)
    worker.currentNode.children.append(newNode)
    var lastWasCR = false
    while let c = g.next() {
        if c == (10) || c == (13) {
            if let allowedChildren = worker.currentNode.description?.allowedChildren, allowedChildren.contains(.br) {
                if c == (13) || (c == (10) && !lastWasCR) {
                    if newNode.value.isEmpty {
                        worker.currentNode.children.removeLast()
                    }
                    newNode = newDOMNode(type: .br, parent: worker.currentNode, tagManager: worker.tagManager)
                    worker.currentNode.children.append(newNode)
                    newNode = newDOMNode(type: .plain, parent: worker.currentNode, tagManager: worker.tagManager)
                    worker.currentNode.children.append(newNode)
                }

                if c == (13) { // \r
                    lastWasCR = true
                } else { // \n
                    lastWasCR = false
                }
            } else {
                if worker.currentNode.type == .code {
                    newNode.value.append(current: g.currentPointer())
                } else {
                    worker.error = BBCodeError.unclosedTag(unclosedTagDetail(unclosedNode: worker.currentNode))
                    return nil
                }
            }
        } else {
            lastWasCR = false

            if c == 91 { // <tag_start>
                if worker.currentNode.description?.allowedChildren != nil {
                    if newNode.value.isEmpty {
                        worker.currentNode.children.removeLast()
                    }
                    return tag_parser
                } else if !worker.currentNode.paired {
                    return tag_parser
                } else {
                    newNode.value.append(current: g.currentPointer())
                }
            } else { // <content>
                newNode.value.append(current: g.currentPointer())
            }
        }
    }

    return nil
}

func tagParser(g: inout USIterator, worker: Worker) -> Parser? {
    //<opening_tag> ::= <opening_tag_1> | <opening_tag_2>
    let newNode: DOMNode = newDOMNode(type: .unknow, parent: worker.currentNode, tagManager: worker.tagManager)
    worker.currentNode.children.append(newNode)
    var index: Int = 0
    let tagNameMaxLength: Int = 8
    var isFirst: Bool = true

    while let c = g.next() {
        if isFirst && c == 47 { // "/"
            if !worker.currentNode.paired {
                //<closing_tag> ::= <tag_start> '/' <tag_name> <tag_end>
                worker.currentNode.children.removeLast()
                return tag_close_parser
            } else {
                // illegal syntax, may be an unpaired closing tag, treat it as plain text
                restoreNodeToPlain(node: newNode, worker: worker, g: g)
                return content_parser
            }
        } else if c == 61 { // "="
            //<opening_tag_2> ::= <tag_prefix> '=' <attr> <tag_end>
            if let tag = worker.tagManager.getInfo(str: newNode.value.toString()) {
                newNode.setTag(tag: tag)
                if let allowedChildren = worker.currentNode.description?.allowedChildren, allowedChildren.contains(newNode.type) {
                    if (newNode.description?.allowAttr)! {
                        newNode.paired = false //isSelfClosing tag has no attr, so its must be not paired
                        worker.currentNode = newNode
                        return attr_parser
                    }
                }
            }
            restoreNodeToPlain(node: newNode, worker: worker, g: g)
            return content_parser
        } else if c == 93 { // "]"
            //<tag> ::= <opening_tag_1> | <opening_tag> <content> <closing_tag>
            if let tag = worker.tagManager.getInfo(str: newNode.value.toString()) {
                newNode.setTag(tag: tag)
                if let allowedChildren = worker.currentNode.description?.allowedChildren, allowedChildren.contains(newNode.type) {
                    if (newNode.description?.isSelfClosing)! {
                        //<opening_tag_1> ::= <tag_prefix> <tag_end>
                        return content_parser
                    } else {
                        //<opening_tag> <content> <closing_tag>
                        newNode.paired = false
                        worker.currentNode = newNode
                        return content_parser
                    }
                }
            }
            restoreNodeToPlain(node: newNode, worker: worker, g: g)
            return content_parser
        } else if c == 91 { // "["
            // illegal syntax, treat it as plain text, and restart tag parsing from this new position
            newNode.setTag(tag: worker.tagManager.getInfo(type: .plain)!)
            //newNode.value.insert(Character(UnicodeScalar(91)), at: newNode.value.startIndex)
            newNode.value.prepend(current: g.currentPointer())
            return tag_parser
        } else {
            if index < tagNameMaxLength {
                newNode.value.append(current: g.currentPointer())
            } else {
                // no such tag
                restoreNodeToPlain(node: newNode, worker: worker, g: g)
                return content_parser
            }
        }
        index = index + 1
        isFirst = false
    }

    worker.error = BBCodeError.unfinishedOpeningTag(unclosedTagDetail(unclosedNode: worker.currentNode))
    return nil
}

func attrParser(g: inout USIterator, worker: Worker) -> Parser? {
    while let c = g.next() {
        if c == 93 { // "]"
            return content_parser
        } else if c == 10 || c == 13 { // LF or CR
            worker.error = BBCodeError.unfinishedAttr(unclosedTagDetail(unclosedNode: worker.currentNode))
            return nil
        } else {
            worker.currentNode.attr.append(current: g.currentPointer())
        }
    }

    //unfinished attr
    worker.error = BBCodeError.unfinishedAttr(unclosedTagDetail(unclosedNode: worker.currentNode))
    return nil
}

func tagClosingParser(g: inout USIterator, worker: Worker) -> Parser? {
    // <tag_name> <tag_end>
    //var tagName: String = ""
    let tagName: BBString = BBString()
    while let c = g.next() {
        if c == 93 { // "]"
            if !tagName.isEmpty && tagName == worker.currentNode.value {
                worker.currentNode.paired = true
                guard let p = worker.currentNode.parent else {
                    // should not happen
                    worker.error = BBCodeError.internalError("bug")
                    return nil
                }
                worker.currentNode = p
                return content_parser
            } else {
                if let allowedChildren = worker.currentNode.description?.allowedChildren {
                    if let tag = worker.tagManager.getInfo(str: tagName.toString()) {
                        if allowedChildren.contains(tag.1) {
                            // not paired tag
                            worker.error = BBCodeError.unpairedTag(unclosedTagDetail(unclosedNode: worker.currentNode))
                            return nil
                        }
                    }
                }

                let newNode: DOMNode = newDOMNode(type: .plain, parent: worker.currentNode, tagManager: worker.tagManager)
                //newNode.value = "[/" + tagName + "]"
                newNode.value.prepend(current: g.currentPointer(), count: 2 + tagName.count)
                newNode.value.append(current: g.currentPointer())
                worker.currentNode.children.append(newNode)

                return content_parser
            }
        } else if c == 91 { // "["
            // illegal syntax, treat it as plain text, and restart tag parsing from this new position
            let newNode: DOMNode = newDOMNode(type: .plain, parent: worker.currentNode, tagManager: worker.tagManager)
            //newNode.value = "[/" + tagName
            newNode.value.prepend(current: g.currentPointer(), count: 2 + tagName.count)
            worker.currentNode.children.append(newNode)
            return tag_parser
        } else if c == 61 { // "="
            // illegal syntax, treat it as plain text
            let newNode: DOMNode = newDOMNode(type: .plain, parent: worker.currentNode, tagManager: worker.tagManager)
            //newNode.value = "[/" + tagName + "="
            newNode.value.prepend(current: g.currentPointer(), count: 2 + tagName.count)
            newNode.value.append(current: g.currentPointer())
            worker.currentNode.children.append(newNode)
            return content_parser
        } else {
            tagName.append(current: g.currentPointer())
        }
    }

    worker.error = BBCodeError.unfinishedClosingTag(unclosedTagDetail(unclosedNode: worker.currentNode))
    return nil
}

func restoreNodeToPlain(node: DOMNode, worker: Worker, g: USIterator) {
    node.setTag(tag: worker.tagManager.getInfo(type: .plain)!)
    node.value.prepend(current: g.currentPointer())
    node.value.append(current: g.currentPointer())
}

func handleNewlineAndParagraph(node: DOMNode, tagManager: TagManager) {
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
        node.children.insert(newDOMNode(type: .paragraphStart, parent: node, tagManager: tagManager), at: 0)
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

            handleNewlineAndParagraph(node: n, tagManager: tagManager)
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
    var text: String = "[" + unclosedNode.value.toString() + (unclosedNode.attr.isEmpty ? "]" : "=" + unclosedNode.attr.toString() + "]")
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
        return node.value.toString()
    } else {
        if let desc = node.description, desc.isSelfClosing {
            return "[" + node.value.toString() + "]"
        } else {
            var text: String = "[" + node.value.toString() + (node.attr.isEmpty ? "]" : "=" + node.attr.toString() + "]")
            for child in node.children {
                text = text + nodeContext(node: child)
            }
            text = text + "[/" + node.value.toString() + "]"

            return text
        }
    }
}

func safeUrl(url: String, defaultScheme: String?, defaultHost: String?) -> String? {
    if var components = URLComponents(string: url) {
        if components.scheme == nil {
            if defaultScheme != nil {
                components.scheme = defaultScheme!
            } else {
                return nil
            }
        }
        if components.host == nil {
            if defaultHost != nil {
                components.host = defaultHost!
            } else {
                return nil
            }
        }
        return components.url?.absoluteString
    }
    return nil
}

let content_parser: Parser = Parser(parse: contentParser)
let tag_parser: Parser = Parser(parse: tagParser)
let tag_close_parser: Parser = Parser(parse: tagClosingParser)
let attr_parser: Parser = Parser(parse: attrParser)

public class BBCode {

    let tagManager: TagManager

    public init() {
        var tags: [TagInfo] = [
            ("", .plain,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                return n.escapedValue })
            ),
            ("", .br,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                return "<br>" })
            ),
            ("", .paragraphStart,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                return "<p>" })
            ),
            ("", .paragraphEnd,
             TagDescription(tagNeeded: false, isSelfClosing: true,
                            allowedChildren: nil,
                            allowAttr: false,
                            isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                return "</p>" })
            ),
            ("quote", .quote,
             TagDescription(tagNeeded: true, isSelfClosing: false,
                            allowedChildren: [.br, .bold, .italic, .underline, .delete, .header, .color, .quote, .code, .hide, .url, .image, .flash, .user, .post, .topic, .smilies],
                            allowAttr: true,
                            isBlock: true,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<div class=\"quotebox\"><blockquote><div>"
                                } else {
                                    html = "<div class=\"quotebox\"><cite>\(n.escapedAttr)</cite><blockquote><div>"
                                }
                                html.append(n.renderChildren(args))
                                html.append("</div></blockquote></div>")
                                return html })
            ),
            ("code", .code,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: false, isBlock: true,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html = "<div class=\"codebox\"><pre><code>"
                                html.append(n.renderChildren(args))
                                html.append("</code></pre></div>")
                                return html })
            ),
            ("hide", .hide,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline, .delete, .header, .color, .quote, .code, .hide, .url, .image, .flash, .user, .post, .topic, .smilies], allowAttr: true, isBlock: true,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                let numberPosts = args?["post number"] as? Int ?? Int(0)
                                var threshold: Int
                                if n.attr.isEmpty {
                                    threshold = 1
                                } else {
                                    threshold = Int(n.attr.toString()) ?? 1
                                    if threshold < 1 {
                                        threshold = 1
                                    }
                                }
                                var html = "<div class=\"quotebox\"><cite>Hidden text</cite><blockquote><div>"
                                if numberPosts >= threshold {
                                    html.append(n.renderChildren(args))
                                } else {
                                    html.append("<p>Post number >= \(threshold) can see")
                                }
                                html.append("</div></blockquote></div>")
                                return html })
            ),
            ("url", .url,
             TagDescription(tagNeeded: true, isSelfClosing: false,
                            allowedChildren: [.image],
                            allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                let scheme = args?["current_scheme"] as? String ?? "http"
                                let host = args?["host"] as? String
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
                                        link = n.renderChildren(args)
                                        if let safeLink = safeUrl(url: link, defaultScheme: scheme, defaultHost: host) {
                                            html = "<a href=\"\(link)\" rel=\"nofollow\">\(safeLink)</a>"
                                        } else {
                                            html = link
                                        }
                                    } else {
                                        html = n.renderChildren(args)
                                    }
                                } else {
                                    link = n.escapedAttr
                                    if let safeLink = safeUrl(url: link, defaultScheme: scheme, defaultHost: host) {
                                        html = "<a href=\"\(safeLink)\" rel=\"nofollow\">\(n.renderChildren(args))</a>"
                                    } else {
                                        html = n.renderChildren(args)
                                    }
                                }
                                return html
             })
            ),
            ("img", .image,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                let scheme = args?["current_scheme"] as? String ?? "http"
                                let host = args?["host"] as? String
                                var html: String
                                let link: String = n.renderChildren(args)
                                if let safeLink = safeUrl(url: link, defaultScheme: scheme, defaultHost: host) {
                                    if n.attr.isEmpty {
                                        html = "<span class=\"postimg\"><img src=\"\(safeLink)\" alt=\"\" /></span>"
                                    } else {
                                        let values = n.attr.toString().components(separatedBy: ",").flatMap { Int($0) }
                                        if values.count == 2 && values[0] > 0 && values[0] <= 4096 && values[1] > 0 && values[1] <= 4096 {
                                            html = "<span class=\"postimg\"><img src=\"\(safeLink)\" alt=\"\" width=\"\(values[0])\" height=\"\(values[1])\" /></span>"
                                        } else {
                                            html = "<span class=\"postimg\"><img src=\"\(safeLink)\" alt=\"\(n.escapedAttr)\" /></span>"
                                        }
                                    }
                                    return html
                                } else {
                                    return link
                                }
             })
            ),
            ("video", .video,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                let scheme = args?["current_scheme"] as? String ?? "http"
                                let host = args?["host"] as? String
                                var html: String
                                let link: String = n.renderChildren(args)
                                if let safeLink = safeUrl(url: link, defaultScheme: scheme, defaultHost: host) {
                                    if n.attr.isEmpty {
                                        html = "<span class=\"postimg\"><video src=\"\(safeLink)\" autoplay loop muted><a href=\"\(safeLink)\">Download</a></video></span>"
                                    } else {
                                        let values = n.attr.toString().components(separatedBy: ",").flatMap { Int($0) }
                                        if values.count == 2 && values[0] > 0 && values[0] <= 4096 && values[1] > 0 && values[1] <= 4096 {
                                            html = "<span class=\"postimg\"><video src=\"\(safeLink)\" width=\"\(values[0])\" height=\"\(values[1])\" autoplay loop muted><a href=\"\(safeLink)\">Download</a></video></span>"
                                        } else {
                                            html = "<span class=\"postimg\"><video src=\"\(safeLink)\" autoplay loop muted><a href=\"\(safeLink)\">Download</a></video></span>"
                                        }
                                    }
                                    return html
                                } else {
                                    return link
                                }
             })
            ),
            ("user", .user,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var userIdStr: String
                                if n.attr.isEmpty {
                                    userIdStr = n.renderChildren(args)
                                    if let userId = UInt32(userIdStr) {
                                        return "<a href=\"/user/\(userId)\">/user/\(userId)</a>"
                                    } else {
                                        return "[user]" + userIdStr + "[/user]"
                                    }
                                } else {
                                    let text = n.renderChildren(args)
                                    if let userId = UInt32(n.attr.toString()) {
                                        return "<a href=\"/user/\(userId)\">\(text)</a>"
                                    } else {
                                        return "[user=\(n.escapedAttr)]\(text)[/user]"
                                    }
                                }
             })
            ),
            ("post", .post,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var postIdStr: String
                                if n.attr.isEmpty {
                                    postIdStr = n.renderChildren(args)
                                    if let postId = UInt32(postIdStr) {
                                        return "<a href=\"/post/\(postId)#\(postId)\">/post/\(postId)</a>"
                                    } else {
                                        return "[post]" + postIdStr + "[/post]"
                                    }
                                } else {
                                    let text = n.renderChildren(args)
                                    if let postId = UInt32(n.attr.toString()) {
                                        return "<a href=\"/post/\(postId)#\(postId)\">\(text)</a>"
                                    } else {
                                        return "[post=\(n.escapedAttr)]\(text)[/post]"
                                    }
                                }
             })
            ),
            ("topic", .topic,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: nil, allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var idStr: String
                                if n.attr.isEmpty {
                                    idStr = n.renderChildren(args)
                                    if let id = UInt32(idStr) {
                                        return "<a href=\"/topic/\(id)\">/topic/\(id)</a>"
                                    } else {
                                        return "[topic]" + idStr + "[/topic]"
                                    }
                                } else {
                                    let text = n.renderChildren(args)
                                    if let id = UInt32(n.attr.toString()) {
                                        return "<a href=\"/topic/\(id)\">\(text)</a>"
                                    } else {
                                        return "[topic=\(n.escapedAttr)]\(text)[/topic]"
                                    }
                                }
             })
            ),
            ("b", .bold,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .italic, .delete, .underline, .url], allowAttr: false, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String = "<b>"
                                html.append(n.renderChildren(args))
                                html.append("</b>")
                                return html })
            ),
            ("i", .italic,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .delete, .underline, .url], allowAttr: false, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String = "<i>"
                                html.append(n.renderChildren(args))
                                html.append("</i>")
                                return html })
            ),
            ("u", .underline,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .delete, .url], allowAttr: false, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String = "<u>"
                                html.append(n.renderChildren(args))
                                html.append("</u>")
                                return html })
            ),
            ("del", .delete,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline, .url], allowAttr: false, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String = "<del>"
                                html.append(n.renderChildren(args))
                                html.append("</del>")
                                return html })
            ),
            ("color", .color,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline], allowAttr: true, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String
                                if n.attr.isEmpty {
                                    html = "<span style=\"color: black\">\(n.renderChildren(args))</span>"
                                } else {
                                    var valid = false
                                    if ["black", "green", "silver", "gray", "olive", "white", "yellow", "maroon", "navy", "red", "blue", "purple", "teal", "fuchsia", "aqua"].contains(n.attr.toString()) {
                                        valid = true
                                    } else {
                                        if n.attr.count == 4 || n.attr.count == 7 {
                                            var g = n.attr.toString().unicodeScalars.makeIterator()
                                            if g.next() == "#" {
                                                while let c = g.next() {
                                                    if (c >= UnicodeScalar("0") && c <= UnicodeScalar("9")) || (c >= UnicodeScalar("a") && c <= UnicodeScalar("z")) || (c >= UnicodeScalar("A") && c <= UnicodeScalar("Z")) {
                                                        valid = true
                                                    } else {
                                                        valid = false
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if valid {
                                        html = "<span style=\"color: \(n.attr.toString())\">\(n.renderChildren(args))</span>"
                                    } else {
                                        html = "[color=\(n.escapedAttr)]\(n.renderChildren(args))[/color]"
                                    }
                                }
                                return html })
            ),
            ("h", .header,
             TagDescription(tagNeeded: true, isSelfClosing: false, allowedChildren: [.br, .bold, .italic, .underline, .delete, .url], allowAttr: false, isBlock: false,
                            render: { (n: DOMNode, args: [String: Any]?) in
                                var html: String = "</p><h5>"
                                html.append(n.renderChildren(args))
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
                                                        render: { (n: DOMNode, args: [String: Any]?) in
                                                            return "<img src=\"/smilies/\(emote.1)\" alt=\"[\(emote.0)]\" />" })))
        }

        // Create .root description
        let rootDescription = TagDescription(tagNeeded: false, isSelfClosing: false,
                                             allowedChildren: [],
                                             allowAttr: false, isBlock: true,
                                             render: { (n: DOMNode, args: [String: Any]?) in
                                                return n.renderChildren(args) })
        for tag in tags {
            rootDescription.allowedChildren?.append(tag.1)
        }
        tags.append(("", .root, rootDescription))

        self.tagManager = TagManager(tags: tags);
    }

    public func parse(bbcode: String, args: [String: Any]? = nil) throws -> String {
        let worker: Worker = Worker(tagManager: tagManager)

        if let domTree = worker.parse(bbcode) {
            handleNewlineAndParagraph(node: domTree, tagManager: tagManager)
            return (domTree.description!.render!(domTree, args))
        } else {
            throw worker.error!
        }
    }

    public func validate(bbcode: String) throws{
        let worker = Worker(tagManager: tagManager)

        guard let _ = worker.parse(bbcode) else {
            throw worker.error!
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
}
