import XCTest
@testable import KwtSMS

final class MessageTests: XCTestCase {

    // MARK: - Preserves normal text

    func testPreservesPlainEnglish() {
        XCTAssertEqual(cleanMessage("Hello World"), "Hello World")
    }

    func testPreservesArabicText() {
        XCTAssertEqual(cleanMessage("مرحبا بالعالم"), "مرحبا بالعالم")
    }

    func testPreservesNewlines() {
        XCTAssertEqual(cleanMessage("Line 1\nLine 2"), "Line 1\nLine 2")
    }

    func testPreservesTabs() {
        XCTAssertEqual(cleanMessage("Col1\tCol2"), "Col1\tCol2")
    }

    func testPreservesSpaces() {
        XCTAssertEqual(cleanMessage("Hello   World"), "Hello   World")
    }

    // MARK: - Arabic digit conversion

    func testConvertsArabicIndicDigits() {
        // ١٢٣٤٥٦ → 123456
        XCTAssertEqual(cleanMessage("\u{0661}\u{0662}\u{0663}\u{0664}\u{0665}\u{0666}"), "123456")
    }

    func testConvertsExtendedArabicIndicDigits() {
        // ۱۲۳۴۵۶ (Persian) → 123456
        XCTAssertEqual(cleanMessage("\u{06F1}\u{06F2}\u{06F3}\u{06F4}\u{06F5}\u{06F6}"), "123456")
    }

    func testMixedArabicTextAndDigits() {
        // "رمز التحقق: ١٢٣٤" → "رمز التحقق: 1234"
        XCTAssertEqual(cleanMessage("رمز التحقق: \u{0661}\u{0662}\u{0663}\u{0664}"), "رمز التحقق: 1234")
    }

    // MARK: - Emoji stripping

    func testStripsSmileys() {
        XCTAssertEqual(cleanMessage("Hello \u{1F600} World"), "Hello  World")
    }

    func testStripsHeart() {
        XCTAssertEqual(cleanMessage("Love \u{2764} you"), "Love  you")
    }

    func testStripsMultipleEmojis() {
        XCTAssertEqual(cleanMessage("\u{1F600}\u{1F601}\u{1F602}Hello"), "Hello")
    }

    func testStripsTransportEmojis() {
        XCTAssertEqual(cleanMessage("Car: \u{1F697}"), "Car: ")
    }

    func testStripsMahjongTile() {
        XCTAssertEqual(cleanMessage("Tile: \u{1F004}"), "Tile: ")
    }

    func testStripsRegionalIndicators() {
        // Flag components
        XCTAssertEqual(cleanMessage("Flag: \u{1F1F0}\u{1F1FC}"), "Flag: ")
    }

    func testStripsVariationSelectors() {
        XCTAssertEqual(cleanMessage("Star: \u{2B50}\u{FE0F}"), "Star: \u{2B50}")
    }

    func testStripsDingbats() {
        XCTAssertEqual(cleanMessage("Check: \u{2714}"), "Check: ")
    }

    func testStripsCombiningKeycap() {
        XCTAssertEqual(cleanMessage("Key: 1\u{20E3}"), "Key: 1")
    }

    func testStripsTagsBlock() {
        XCTAssertEqual(cleanMessage("Tag: \u{E0001}"), "Tag: ")
    }

    // MARK: - Hidden invisible characters

    func testStripsBOM() {
        XCTAssertEqual(cleanMessage("\u{FEFF}Hello"), "Hello")
    }

    func testStripsZeroWidthSpace() {
        XCTAssertEqual(cleanMessage("He\u{200B}llo"), "Hello")
    }

    func testStripsZeroWidthNonJoiner() {
        XCTAssertEqual(cleanMessage("He\u{200C}llo"), "Hello")
    }

    func testStripsZeroWidthJoiner() {
        XCTAssertEqual(cleanMessage("He\u{200D}llo"), "Hello")
    }

    func testStripsSoftHyphen() {
        XCTAssertEqual(cleanMessage("Hel\u{00AD}lo"), "Hello")
    }

    func testStripsWordJoiner() {
        XCTAssertEqual(cleanMessage("He\u{2060}llo"), "Hello")
    }

    func testStripsObjectReplacement() {
        XCTAssertEqual(cleanMessage("He\u{FFFC}llo"), "Hello")
    }

    // MARK: - Directional formatting

    func testStripsLTRMark() {
        XCTAssertEqual(cleanMessage("He\u{200E}llo"), "Hello")
    }

    func testStripsRTLMark() {
        XCTAssertEqual(cleanMessage("He\u{200F}llo"), "Hello")
    }

    func testStripsLRE() {
        XCTAssertEqual(cleanMessage("He\u{202A}llo"), "Hello")
    }

    func testStripsDirectionalIsolates() {
        XCTAssertEqual(cleanMessage("He\u{2066}llo\u{2069}"), "Hello")
    }

    // MARK: - C0/C1 control characters

    func testStripsNullByte() {
        XCTAssertEqual(cleanMessage("He\u{0000}llo"), "Hello")
    }

    func testStripsBell() {
        XCTAssertEqual(cleanMessage("He\u{0007}llo"), "Hello")
    }

    func testStripsDEL() {
        XCTAssertEqual(cleanMessage("He\u{007F}llo"), "Hello")
    }

    func testStripsC1Controls() {
        XCTAssertEqual(cleanMessage("He\u{0080}llo"), "Hello")
        XCTAssertEqual(cleanMessage("He\u{009F}llo"), "Hello")
    }

    // MARK: - HTML stripping

    func testStripsBoldTags() {
        XCTAssertEqual(cleanMessage("<b>Hello</b>"), "Hello")
    }

    func testStripsParagraphTags() {
        XCTAssertEqual(cleanMessage("<p>Hello</p>"), "Hello")
    }

    func testStripsTagsWithAttributes() {
        XCTAssertEqual(cleanMessage("<a href=\"url\">link</a>"), "link")
    }

    func testStripsSelfClosingTags() {
        XCTAssertEqual(cleanMessage("Hello<br/>World"), "HelloWorld")
    }

    // MARK: - Combined scenarios

    func testArabicTextWithEmojisAndDigits() {
        let input = "مرحبا \u{1F600} \u{0661}\u{0662}\u{0663}"
        let expected = "مرحبا  123"
        XCTAssertEqual(cleanMessage(input), expected)
    }

    func testBOMPlusHTMLPlusEmoji() {
        let input = "\u{FEFF}<b>Hello \u{1F600}</b>"
        XCTAssertEqual(cleanMessage(input), "Hello ")
    }

    func testEmptyAfterCleaning() {
        XCTAssertEqual(cleanMessage("\u{1F600}\u{1F601}\u{1F602}"), "")
    }

    func testEmptyString() {
        XCTAssertEqual(cleanMessage(""), "")
    }
}
