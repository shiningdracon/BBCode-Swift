import XCTest
@testable import BBCode

class BBCodeTests: XCTestCase {
    func testBold() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[b]test[/b]"), "<p><b>test</b>")
    }

    func testItalic() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[i]test[/i]"), "<p><i>test</i>")
    }

    func testColor() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[color=#FF0000]Red text[/color]"), "<p><span style=\"color: #FF0000\">Red text</span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[color=blue]Blue text[/color]"), "<p><span style=\"color: blue\">Blue text</span>")
    }

    func testUrl() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[url]http://example.com/1.jpg[/url]"), "<p><a href=\"http://example.com/1.jpg\" rel=\"nofollow\">http://example.com/1.jpg</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[url=http://example.com/1.jpg]File 1.jpg[/url]"), "<p><a href=\"http://example.com/1.jpg\" rel=\"nofollow\">File 1.jpg</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[url=https://'asf'.com]File 1.jpg[/url]"), "<p>File 1.jpg")
        XCTAssertEqual(try BBCode().parse(bbcode: "[url=javascript:alert(String.fromCharCode(88,83,83))]http://google.com[/url]"), "<p>http://google.com")
    }

    func testImg() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[img]http://example.com/1.jpg[/img]"), "<p><span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"\" /></span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[img=gugu,alt]http://example.com/1.jpg[/img]"), "<p><span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"gugu,alt\" /></span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[img=300,500]http://example.com/1.jpg[/img]"), "<p><span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"\" width=\"300\" height=\"500\" /></span>")
    }

    func testQuote() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[quote]balabala[b]bala[/b][/quote]"), "<div class=\"quotebox\"><blockquote><div><p>balabala<b>bala</b></div></blockquote></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[quote][quote][quote]test[/quote][/quote][/quote]"), "<div class=\"quotebox\"><blockquote><div><div class=\"quotebox\"><blockquote><div><div class=\"quotebox\"><blockquote><div><p>test</div></blockquote></div></div></blockquote></div></div></blockquote></div>")
    }

    func testSmilies() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[大笑]"), "<p><img src=\"/smilies/haku-laugh.png\" alt=\"\" />")
    }

    func testUser() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[user=2]Test user[/user]"), "<p><a href=\"/forum/user/2\">Test user</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[user]2[/user]"), "<p><a href=\"/forum/user/2\">/forum/user/2</a>")
    }

    func testCode() {
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text\n[b] Not bold [/b] [/code] [b] bold [/b]"), "<p>Test <div class=\"codebox\"><pre><code> coded text\n[b] Not bold [/b] </code></pre></div> <b> bold </b>")
    }

    func testMix() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[[大笑]"), "<p>[<img src=\"/smilies/haku-laugh.png\" alt=\"\" />")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b] [/code]"), "<p>Test <div class=\"codebox\"><pre><code> coded text [/b] </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b] [/code][/code]"), "<p>Test <div class=\"codebox\"><pre><code> coded text [/b] </code></pre></div>[/code]")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b [/code]"), "<p>Test <div class=\"codebox\"><pre><code> coded text [/b </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [//[[[[[[[[ [/code]"), "<p>Test <div class=\"codebox\"><pre><code> coded text [//[[[[[[[[ </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[b=abc]xyz[/b]"), "<p>[b=abc]xyz[/b]")
    }

    func testNewline() {
        XCTAssertEqual(try BBCode().parse(bbcode: "text\nnextline\r\n3rd line\r4th line"), "<p>text<br>nextline<br>3rd line<br>4th line")
    }

    func testNewlineAfterBlock() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[quote]text\r\n2\r\n[/quote]\nnextline\r\n3rd line\r4th line"), "<div class=\"quotebox\"><blockquote><div><p>text<br>2</div></blockquote></div>nextline<br>3rd line<br>4th line")
    }
}
