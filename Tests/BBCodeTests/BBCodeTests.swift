import XCTest
@testable import BBCode

class BBCodeTests: XCTestCase {
    func testBold() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[b]test[/b]"), "<b>test</b>")
    }

    func testItalic() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[i]test[/i]"), "<i>test</i>")
    }

    func testColor() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[color=#FF0000]Red text[/color]"), "<span style=\"color: #FF0000\">Red text</span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[color=blue]Blue text[/color]"), "<span style=\"color: blue\">Blue text</span>")
    }

    func testUrl() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[url]http://example.com/1.jpg[/url]"), "<a href=\"http://example.com/1.jpg\" rel=\"nofollow\">http://example.com/1.jpg</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[url=http://example.com/1.jpg]File 1.jpg[/url]"), "<a href=\"http://example.com/1.jpg\" rel=\"nofollow\">File 1.jpg</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[url=https://'asf'.com]File 1.jpg[/url]"), "File 1.jpg")
    }

    func testImg() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[img]http://example.com/1.jpg[/img]"), "<span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"\" /></span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[img=gugu,alt]http://example.com/1.jpg[/img]"), "<span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"gugu,alt\" /></span>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[img=300,500]http://example.com/1.jpg[/img]"), "<span class=\"postimg\"><img src=\"http://example.com/1.jpg\" alt=\"\" width=\"300\" height=\"500\" /></span>")
    }

    func testQuote() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[quote]balabala[b]bala[/b][/quote]"), "<div class=\"quotebox\"><blockquote><div><p>balabala<b>bala</b></p></div></blockquote></div>")
    }

    func testSmilies() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[大笑]"), "<img src=\"/smilies/haku-laugh.png\" alt=\"\" />")
    }

    func testUser() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[user=2]Test user[/user]"), "<a href=\"/forum/user/2\">Test user</a>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[user]2[/user]"), "<a href=\"/forum/user/2\">/forum/user/2</a>")
    }

    func testCode() {
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [b] Not bold [/b] [/code] [b] bold [/b]"), "Test <div class=\"codebox\"><pre><code> coded text [b] Not bold [/b] </code></pre></div> <b> bold </b>")
    }

    func testMix() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[[大笑]"), "[<img src=\"/smilies/haku-laugh.png\" alt=\"\" />")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b] [/code]"), "Test <div class=\"codebox\"><pre><code> coded text [/b] </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b] [/code][/code]"), "Test <div class=\"codebox\"><pre><code> coded text [/b] </code></pre></div>[/code]")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [/b [/code]"), "Test <div class=\"codebox\"><pre><code> coded text [/b </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "Test [code] coded text [//[[[[[[[[ [/code]"), "Test <div class=\"codebox\"><pre><code> coded text [//[[[[[[[[ </code></pre></div>")
        XCTAssertEqual(try BBCode().parse(bbcode: "[b=abc]xyz[/b]"), "[b=abc]xyz[/b]")
    }

    func testNewline() {
        XCTAssertEqual(try BBCode().parse(bbcode: "text\nnextline\r\n3rd line\r4th line"), "text<br>nextline<br>3rd line<br>4th line")
    }

    func testNewlineAfterBlock() {
        XCTAssertEqual(try BBCode().parse(bbcode: "[quote]text[/quote]\nnextline\r\n3rd line\r4th line"), "<div class=\"quotebox\"><blockquote><div><p>text</p></div></blockquote></div>nextline<br>3rd line<br>4th line")
    }
}
