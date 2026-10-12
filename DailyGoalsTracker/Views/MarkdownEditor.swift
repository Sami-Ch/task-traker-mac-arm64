import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Rich Text Helpers

/// Paragraph styles for the journal editor
enum JournalParagraphStyle: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case title = "Title"
    case subtitle = "Subtitle"
    case heading1 = "Heading 1"
    case heading2 = "Heading 2"
    case heading3 = "Heading 3"
    case quote = "Quote"
    
    var id: String { rawValue }
    
    var fontSize: CGFloat {
        switch self {
        case .normal: return 16
        case .title: return 32
        case .subtitle: return 20
        case .heading1: return 28
        case .heading2: return 24
        case .heading3: return 20
        case .quote: return 16
        }
    }
    
    var fontWeight: NSFont.Weight {
        switch self {
        case .normal, .quote: return .regular
        case .title, .heading1: return .bold
        case .subtitle, .heading2, .heading3: return .semibold
        }
    }
    
    var textColor: NSColor {
        switch self {
        case .quote: return JournalPageColors.quoteInk
        default: return JournalPageColors.ink
        }
    }
    
    func paragraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        switch self {
        case .normal:
            style.paragraphSpacing = 12
        case .title:
            style.paragraphSpacing = 8
            style.paragraphSpacingBefore = 16
        case .subtitle:
            style.paragraphSpacing = 16
        case .heading1:
            style.paragraphSpacing = 8
            style.paragraphSpacingBefore = 24
        case .heading2:
            style.paragraphSpacing = 6
            style.paragraphSpacingBefore = 20
        case .heading3:
            style.paragraphSpacing = 4
            style.paragraphSpacingBefore = 16
        case .quote:
            style.paragraphSpacing = 8
            style.headIndent = 20
            style.firstLineHeadIndent = 20
        }
        return style
    }
    
    func font() -> NSFont {
        NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    }
    
    func attributes() -> [NSAttributedString.Key: Any] {
        [
            .font: font(),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle()
        ]
    }
}

/// Text colors in the toolbar. "Default" follows the system label color.
enum JournalTextColor: String, CaseIterable, Identifiable {
    case automatic = "Default"
    case gray = "Gray"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    
    var id: String { rawValue }
    
    var nsColor: NSColor {
        switch self {
        case .automatic: return .textColor
        case .gray: return .secondaryLabelColor
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        }
    }
    
    var swiftUIColor: Color { Color(nsColor: nsColor) }
}

/// Resolved journal page and ink colors.
enum JournalPageColors {
    /// Soft paper. Pure white in light mode is harsher to read for long stretches.
    static let warm = NSColor(srgbRed: 0.965, green: 0.953, blue: 0.933, alpha: 1)
    static let sepia = NSColor(srgbRed: 0.957, green: 0.925, blue: 0.855, alpha: 1)
    static let mist = NSColor(srgbRed: 0.925, green: 0.941, blue: 0.957, alpha: 1)
    /// Near-black. Easier on a light page than pure black, still well above reading contrast.
    static let lightInk = NSColor(srgbRed: 0.145, green: 0.145, blue: 0.165, alpha: 1)
    static let darkInk = NSColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1)
    
    /// Foreground used for new body text. Updated when the page color changes.
    static var ink: NSColor = .textColor
    static var quoteInk: NSColor = .secondaryLabelColor
    
    static func paper(for choice: JournalPaper, custom: JournalRGB?, scheme: ColorScheme) -> NSColor {
        switch choice {
        case .automatic:
            return scheme == .dark ? .textBackgroundColor : warm
        case .white:
            return .white
        case .warm:
            return warm
        case .sepia:
            return sepia
        case .mist:
            return mist
        case .custom:
            return custom?.nsColor ?? warm
        }
    }
    
    static func ink(for paper: NSColor, choice: JournalPaper, scheme: ColorScheme) -> NSColor {
        if choice == .automatic {
            return scheme == .dark ? .textColor : lightInk
        }
        return isLight(paper) ? lightInk : darkInk
    }
    
    static func quoteInk(for ink: NSColor) -> NSColor {
        ink.withAlphaComponent(0.75)
    }
    
    static func isLight(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return true }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance > 0.62
    }
    
    /// Body text that should follow the page, not a color the user picked.
    static func isAutomaticBody(_ color: NSColor, ink: NSColor) -> Bool {
        let known: [NSColor] = [.textColor, .labelColor, .black, .white, lightInk, darkInk, ink]
        return known.contains { color.isClose(to: $0, tolerance: 0.06) }
    }
}

extension JournalRGB {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }
    
    init(nsColor: NSColor) {
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}

/// Highlight colors available in the editor
enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow = "Yellow"
    case green = "Green"
    case pink = "Pink"
    case blue = "Blue"
    case none = "None"
    
    var id: String { rawValue }
    
    var color: NSColor? {
        switch self {
        case .yellow: return NSColor.yellow.withAlphaComponent(0.4)
        case .green: return NSColor.green.withAlphaComponent(0.3)
        case .pink: return NSColor.systemPink.withAlphaComponent(0.3)
        case .blue: return NSColor.systemBlue.withAlphaComponent(0.25)
        case .none: return nil
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .yellow: return .yellow
        case .green: return .green
        case .pink: return .pink
        case .blue: return .blue
        case .none: return .clear
        }
    }
}

/// Line spacing options
enum LineSpacing: Double, CaseIterable, Identifiable {
    case single = 1.0
    case onePointFifteen = 1.15
    case onePointFive = 1.5
    case double = 2.0
    
    var id: Double { rawValue }
    
    var label: String {
        switch self {
        case .single: return "1.0"
        case .onePointFifteen: return "1.15"
        case .onePointFive: return "1.5"
        case .double: return "2.0"
        }
    }
}

/// Available font sizes
let journalFontSizes: [CGFloat] = [10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48]

// MARK: - Rich Text Conversion

enum JournalRichText {
    /// Default attributes for new text
    static func defaultAttributes() -> [NSAttributedString.Key: Any] {
        JournalParagraphStyle.normal.attributes()
    }
    
    /// Create an empty attributed string with default styling
    static func defaultAttributedString() -> NSAttributedString {
        NSAttributedString(string: "", attributes: defaultAttributes())
    }
    
    /// Convert legacy markdown to rich text
    static func fromMarkdown(_ source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = source.components(separatedBy: "\n")
        var activeList: (format: NSTextList.MarkerFormat, list: NSTextList)?
        
        for (index, line) in lines.enumerated() {
            var processedLine = line
            var style = JournalParagraphStyle.normal
            var listFormat: NSTextList.MarkerFormat?
            
            // Handle headings
            if let match = processedLine.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                let level = processedLine[match].filter { $0 == "#" }.count
                processedLine = String(processedLine[match.upperBound...])
                switch level {
                case 1: style = .heading1
                case 2: style = .heading2
                default: style = .heading3
                }
            }
            // Handle blockquotes
            else if processedLine.hasPrefix("> ") {
                processedLine = String(processedLine.dropFirst(2))
                style = .quote
            }
            else if let match = processedLine.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
                processedLine = String(processedLine[match.upperBound...])
                listFormat = .disc
            } else if let match = processedLine.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                processedLine = String(processedLine[match.upperBound...])
                listFormat = JournalTextLists.numberedMarker
            }

            if let listFormat {
                if activeList?.format != listFormat {
                    activeList = (listFormat, NSTextList(markerFormat: listFormat, options: 0))
                }
            } else {
                activeList = nil
            }

            let paragraph = style.paragraphStyle()
            if let list = activeList?.list {
                paragraph.textLists = [list]
                JournalTextLists.applyIndent(paragraph)
            }
            var attributes = style.attributes()
            attributes[.paragraphStyle] = paragraph
            let lineAttr = NSMutableAttributedString(string: processedLine, attributes: attributes)
            
            // Apply inline formatting
            applyInlineFormatting(to: lineAttr, baseFont: style.font())
            
            result.append(lineAttr)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
        
        return result
    }
    
    private static func applyInlineFormatting(to attrString: NSMutableAttributedString, baseFont: NSFont) {
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        
        // Highlight ==text==
        applyPatternSimple(#"==([^=\n]+)=="#, to: attrString, markers: 2) { range in
            attrString.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.4), range: range)
        }
        
        // Bold **text** or __text__
        for pattern in [#"\*\*([^*\n]+)\*\*"#, #"__([^_\n]+)__"#] {
            applyPatternSimple(pattern, to: attrString, markers: 2) { range in
                attrString.addAttribute(.font, value: boldFont, range: range)
            }
        }
        
        // Italic *text* or _text_
        for pattern in [#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, #"(?<!_)_([^_\n]+)_(?!_)"#] {
            applyPatternSimple(pattern, to: attrString, markers: 1) { range in
                attrString.addAttribute(.font, value: italicFont, range: range)
            }
        }
        
        // Strikethrough ~~text~~
        applyPatternSimple(#"~~([^~\n]+)~~"#, to: attrString, markers: 2) { range in
            attrString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        // Links [text](url)
        let linkPattern = #"\[([^\]\n]+)\]\(([^)\n]+)\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            var offset = 0
            let matches = regex.matches(in: attrString.string, options: [], range: NSRange(location: 0, length: attrString.length))
            for match in matches {
                let adjustedRange = NSRange(location: match.range.location - offset, length: match.range.length)
                let textRange = NSRange(location: match.range(at: 1).location - offset, length: match.range(at: 1).length)
                let urlRange = match.range(at: 2)
                
                let linkText = (attrString.string as NSString).substring(with: textRange)
                let urlText = ((attrString.string as NSString).substring(with: NSRange(location: urlRange.location - offset, length: urlRange.length)))
                
                attrString.replaceCharacters(in: adjustedRange, with: linkText)
                let newRange = NSRange(location: adjustedRange.location, length: linkText.count)
                attrString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: newRange)
                attrString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
                if let url = URL(string: urlText) {
                    attrString.addAttribute(.link, value: url, range: newRange)
                }
                
                offset += match.range.length - linkText.count
            }
        }
    }
    
    private static func applyPatternSimple(_ pattern: String, to attrString: NSMutableAttributedString, markers: Int, apply: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        var offset = 0
        let text = attrString.string
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        for match in matches {
            let adjustedRange = NSRange(location: match.range.location - offset, length: match.range.length)
            let innerRange = NSRange(location: adjustedRange.location, length: adjustedRange.length - markers * 2)
            
            // Remove end markers
            attrString.replaceCharacters(in: NSRange(location: adjustedRange.location + adjustedRange.length - markers, length: markers), with: "")
            // Remove start markers
            attrString.replaceCharacters(in: NSRange(location: adjustedRange.location, length: markers), with: "")
            
            apply(innerRange)
            offset += markers * 2
        }
    }
    
    /// Export attributed string to Markdown
    static func toMarkdown(_ attrString: NSAttributedString) -> String {
        var result = ""
        let text = attrString.string
        
        // Process by paragraph
        var paragraphStart = 0
        while paragraphStart < text.count {
            let startIndex = text.index(text.startIndex, offsetBy: paragraphStart)
            let lineRange = text.lineRange(for: startIndex...startIndex)
            let endOffset = text.distance(from: text.startIndex, to: lineRange.upperBound)
            let nsRange = NSRange(location: paragraphStart, length: endOffset - paragraphStart)
            
            let paragraphText = (text as NSString).substring(with: nsRange)
            var mdLine = ""
            
            // Check paragraph style from first character
            if nsRange.length > 0 {
                var effectiveRange = NSRange()
                let attrs = attrString.attributes(at: nsRange.location, effectiveRange: &effectiveRange)
                
                if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
                   let list = paragraphStyle.textLists.last {
                    let indent = String(repeating: "  ", count: max(0, paragraphStyle.textLists.count - 1))
                    let indentMarker: String
                    if list.isOrdered {
                        let number = max(1, attrString.itemNumber(in: list, at: nsRange.location))
                        indentMarker = "\(number). "
                    } else {
                        indentMarker = "- "
                    }
                    mdLine = "\(indent)\(indentMarker)"
                } else if let font = attrs[.font] as? NSFont {
                    let fontSize = font.pointSize
                    let isBold = NSFontManager.shared.traits(of: font).contains(.boldFontMask)
                    
                    if fontSize >= 28 && isBold {
                        mdLine = "# "
                    } else if fontSize >= 24 && isBold {
                        mdLine = "## "
                    } else if fontSize >= 20 && isBold {
                        mdLine = "### "
                    }
                }
                
                if mdLine.isEmpty, let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle, paragraphStyle.headIndent > 0 {
                    mdLine = "> "
                }
            }
            
            // Process inline formatting within paragraph
            var charIndex = nsRange.location
            while charIndex < nsRange.location + nsRange.length {
                var effectiveRange = NSRange()
                let attrs = attrString.attributes(at: charIndex, effectiveRange: &effectiveRange)
                let charEnd = min(effectiveRange.location + effectiveRange.length, nsRange.location + nsRange.length)
                let segmentRange = NSRange(location: charIndex, length: charEnd - charIndex)
                var segment = (text as NSString).substring(with: segmentRange)
                
                // Skip the newline at the end
                let trimmedSegment = segment.replacingOccurrences(of: "\n", with: "")
                if !trimmedSegment.isEmpty {
                    // Check for link
                    if let link = attrs[.link] as? URL {
                        segment = "[\(trimmedSegment)](\(link.absoluteString))"
                    } else {
                        // Check for formatting
                        let font = attrs[.font] as? NSFont
                        let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
                        let isBold = traits.contains(.boldFontMask)
                        let isItalic = traits.contains(.italicFontMask)
                        let hasStrike = (attrs[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue
                        let hasUnderline = (attrs[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
                        let hasHighlight = attrs[.backgroundColor] != nil
                        
                        var formatted = trimmedSegment
                        
                        // Only apply inline formatting if not a heading (which already has bold)
                        if !mdLine.hasPrefix("#") {
                            if isBold { formatted = "**\(formatted)**" }
                            if isItalic { formatted = "*\(formatted)*" }
                        }
                        if hasStrike { formatted = "~~\(formatted)~~" }
                        if hasHighlight { formatted = "==\(formatted)==" }
                        if hasUnderline && !attrs.keys.contains(.link) { formatted = "<u>\(formatted)</u>" }
                        
                        segment = formatted
                    }
                    mdLine += segment
                }
                
                charIndex = charEnd
            }
            
            // Handle scene breaks
            let trimmedLine = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine == "* * *" || trimmedLine == "⁂" {
                mdLine = "\n* * *\n"
            }
            
            result += mdLine
            if !paragraphText.hasSuffix("\n") && paragraphStart + nsRange.length < text.count {
                result += "\n"
            }
            
            paragraphStart = endOffset
        }
        
        return result
    }
}

// MARK: - Legacy Markdown helpers (kept for preview compatibility)

enum JournalMarkdown {
    /// Strip common markdown so previews stay readable.
    static func plainText(from source: String) -> String {
        var text = source
        let patterns = [
            #"==([^=]+)=="#,
            #"\*\*([^*]+)\*\*"#,
            #"__([^_]+)__"#,
            #"\*([^*]+)\*"#,
            #"_([^_]+)_"#,
            #"~~([^~]+)~~"#,
            #"`([^`]+)`"#,
            #"^#{1,6}\s+"#,
            #"^\>\s+"#,
            #"^[-*+]\s+"#,
            #"^\d+\.\s+"#,
            #"\[([^\]]+)\]\([^)]+\)"#
        ]
        for pattern in patterns {
            text = text.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        }
        return text
    }
}

// MARK: - Text lists

/// Bullet and numbered lists use `NSTextList` on TextKit 2.
/// The text view draws the markers and, on Return, Tab, and Shift-Tab, continues,
/// exits, and nests them. Item numbers come from the shared list object, so a
/// selection of several paragraphs stays sequential without a hand-rolled counter.
enum JournalTextLists {
    /// Word and Docs use "1." AppKit's built-in `.decimal` marker is just "1".
    /// The format string is still an `NSTextList`, so Return keeps numbering.
    static let numberedMarker = NSTextList.MarkerFormat(rawValue: "{decimal}.")
    static let bulletMarker = NSTextList.MarkerFormat.disc
    private static let indentStep: CGFloat = 36
    private static let legacyMarker = try! NSRegularExpression(
        pattern: #"^(?:•\s+|[-*+]\s+|\d+\.\s+)"#
    )
    
    static func applyIndent(_ style: NSMutableParagraphStyle) {
        let level = style.textLists.count
        if level == 0 {
            style.headIndent = 0
            style.firstLineHeadIndent = 0
        } else {
            style.headIndent = CGFloat(level) * indentStep
            style.firstLineHeadIndent = CGFloat(level - 1) * indentStep
        }
    }
    
    static func containsList(_ text: NSAttributedString) -> Bool {
        guard text.length > 0 else { return false }
        var found = false
        text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if let style = value as? NSParagraphStyle, !style.textLists.isEmpty {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
    
    /// Turns old "`• `" / "`1. `" prefixes into real list paragraphs so Return keeps numbering.
    static func normalizeLegacyMarkers(_ source: NSAttributedString) -> NSAttributedString {
        let text = source.string as NSString
        guard text.length > 0 else { return source }
        
        var groups: [(NSTextList.MarkerFormat, [NSRange])] = []
        var location = 0
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            let style = source.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
            if style?.textLists.isEmpty != false, let format = legacyFormat(of: text.substring(with: paragraph)) {
                if groups.last?.0 == format {
                    groups[groups.count - 1].1.append(paragraph)
                } else {
                    groups.append((format, [paragraph]))
                }
            }
            let next = NSMaxRange(paragraph)
            if next <= location { break }
            location = next
        }
        guard !groups.isEmpty else { return source }
        
        let result = NSMutableAttributedString(attributedString: source)
        for group in groups.reversed() {
            let list = NSTextList(markerFormat: group.0, options: 0)
            for paragraph in group.1.reversed() {
                stripLegacyMarker(from: paragraph, in: result)
                guard result.length > 0 else { continue }
                let location = min(paragraph.location, result.length - 1)
                let updated = (result.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                setList(list, on: updated, in: result)
            }
        }
        return result
    }
    
    /// Copy used by Word export. AppKit's docx writer does not emit numbering,
    /// so the markers have to be real characters in that file.
    static func withPrintedMarkers(_ source: NSAttributedString) -> NSAttributedString {
        let text = source.string as NSString
        guard text.length > 0, containsList(source) else { return source }
        let result = NSMutableAttributedString()
        var location = 0
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            let chunk = source.attributedSubstring(from: paragraph)
            if chunk.length > 0,
               let style = chunk.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
               let list = style.textLists.last {
                let item = max(1, source.itemNumber(in: list, at: paragraph.location))
                let token = list.marker(forItemNumber: item) + " "
                let indent = String(repeating: "\t", count: max(0, style.textLists.count - 1))
                result.append(NSAttributedString(string: indent + token, attributes: chunk.attributes(at: 0, effectiveRange: nil)))
            }
            result.append(chunk)
            let next = NSMaxRange(paragraph)
            if next <= location { break }
            location = next
        }
        return result
    }
    
    static func toggle(_ format: NSTextList.MarkerFormat, in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        if storage.length == 0 {
            installEmptyParagraph(format, in: textView)
            return
        }
        
        let text = storage.string as NSString
        var selection = textView.selectedRange()
        if selection.location >= text.length {
            selection = NSRange(location: text.length - 1, length: 0)
        }
        let paragraphs = paragraphRanges(in: text, covering: selection)
        guard let first = paragraphs.first else { return }
        let covered = NSRange(location: first.location, length: NSMaxRange(paragraphs[paragraphs.count - 1]) - first.location)
        let remove = paragraphs.allSatisfy { innermostFormat(at: $0, in: storage) == format }
        
        guard textView.shouldChangeText(in: covered, replacementString: nil) else { return }
        textView.undoManager?.beginUndoGrouping()
        storage.beginEditing()
        if remove {
            for paragraph in paragraphs.reversed() {
                removeInnermostList(on: paragraph, in: storage)
            }
        } else {
            let list = existingList(before: first.location, format: format, in: storage)
                ?? NSTextList(markerFormat: format, options: 0)
            for paragraph in paragraphs.reversed() {
                if innermostFormat(at: paragraph, in: storage) == nil {
                    stripLegacyMarker(from: paragraph, in: storage)
                }
                if storage.length == 0 {
                    storage.setAttributedString(emptyListParagraph(list))
                    continue
                }
                let location = min(paragraph.location, storage.length - 1)
                let updated = (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                setList(list, on: updated, in: storage)
            }
        }
        storage.endEditing()
        clampSelection(in: textView)
        textView.didChangeText()
        restoreTypingAttributes(in: textView)
        textView.undoManager?.endUndoGrouping()
    }
    
    private static func emptyListParagraph(_ list: NSTextList) -> NSAttributedString {
        let paragraph = JournalParagraphStyle.normal.paragraphStyle()
        paragraph.textLists = [list]
        applyIndent(paragraph)
        var attributes = JournalRichText.defaultAttributes()
        attributes[.paragraphStyle] = paragraph
        return NSAttributedString(string: "\n", attributes: attributes)
    }
    
    private static func installEmptyParagraph(_ format: NSTextList.MarkerFormat, in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let replacement = emptyListParagraph(NSTextList(markerFormat: format, options: 0))
        guard textView.shouldChangeText(in: NSRange(location: 0, length: 0), replacementString: "\n") else { return }
        textView.undoManager?.beginUndoGrouping()
        storage.setAttributedString(replacement)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.didChangeText()
        restoreTypingAttributes(in: textView)
        textView.undoManager?.endUndoGrouping()
    }
    
    private static func paragraphRanges(in string: NSString, covering range: NSRange) -> [NSRange] {
        guard string.length > 0 else { return [] }
        var probe = range
        if probe.location >= string.length {
            probe = NSRange(location: string.length - 1, length: 0)
        }
        let span = string.paragraphRange(for: probe)
        var ranges: [NSRange] = []
        var location = span.location
        let end = NSMaxRange(span)
        while location < end {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(paragraph)
            let next = NSMaxRange(paragraph)
            if next <= location { break }
            location = next
        }
        return ranges
    }
    
    private static func innermostFormat(at paragraph: NSRange, in text: NSAttributedString) -> NSTextList.MarkerFormat? {
        guard paragraph.location < text.length else { return nil }
        let style = text.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
        return style?.textLists.last?.markerFormat
    }
    
    private static func existingList(before location: Int, format: NSTextList.MarkerFormat, in text: NSAttributedString) -> NSTextList? {
        guard location > 0, location <= text.length else { return nil }
        let previous = (text.string as NSString).paragraphRange(for: NSRange(location: location - 1, length: 0))
        guard previous.location < location,
              let style = text.attribute(.paragraphStyle, at: previous.location, effectiveRange: nil) as? NSParagraphStyle,
              let list = style.textLists.last,
              list.markerFormat == format else { return nil }
        return list
    }
    
    private static func setList(_ list: NSTextList, on paragraph: NSRange, in text: NSMutableAttributedString) {
        guard paragraph.location < text.length, paragraph.length > 0 else { return }
        let existing = text.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
        let style = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? JournalParagraphStyle.normal.paragraphStyle()
        var lists = style.textLists
        if lists.isEmpty {
            lists = [list]
        } else {
            lists[lists.count - 1] = list
        }
        style.textLists = lists
        applyIndent(style)
        text.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }
    
    private static func removeInnermostList(on paragraph: NSRange, in text: NSMutableAttributedString) {
        guard paragraph.location < text.length, paragraph.length > 0,
              let existing = text.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle,
              !existing.textLists.isEmpty else { return }
        let style = existing.mutableCopy() as! NSMutableParagraphStyle
        var lists = style.textLists
        lists.removeLast()
        style.textLists = lists
        applyIndent(style)
        text.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }
    
    private static func stripLegacyMarker(from paragraph: NSRange, in text: NSMutableAttributedString) {
        guard paragraph.location < text.length else { return }
        let current = text.string as NSString
        let slice = current.substring(with: paragraph)
        let markerLength = legacyMarkerLength(in: slice)
        guard markerLength > 0, paragraph.location + markerLength <= current.length else { return }
        text.replaceCharacters(in: NSRange(location: paragraph.location, length: markerLength), with: "")
    }
    
    private static func legacyFormat(of paragraph: String) -> NSTextList.MarkerFormat? {
        let body = paragraph.hasSuffix("\n") ? String(paragraph.dropLast()) : paragraph
        if body.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil { return numberedMarker }
        if body.range(of: #"^(?:•|[-*+])\s+"#, options: .regularExpression) != nil { return .disc }
        return nil
    }
    
    private static func legacyMarkerLength(in paragraph: String) -> Int {
        let body = paragraph.hasSuffix("\n") ? String(paragraph.dropLast()) : paragraph
        let ns = body as NSString
        guard ns.length > 0,
              let match = legacyMarker.firstMatch(in: body, range: NSRange(location: 0, length: ns.length)),
              match.range.location == 0 else { return 0 }
        return match.range.length
    }
    
    private static func clampSelection(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        var selected = textView.selectedRange()
        if selected.location > storage.length { selected.location = storage.length }
        if NSMaxRange(selected) > storage.length {
            selected.length = storage.length - selected.location
        }
        textView.setSelectedRange(selected)
    }
    
    private static func restoreTypingAttributes(in textView: NSTextView) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let location = min(max(0, textView.selectedRange().location), storage.length - 1)
        guard let style = storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) else { return }
        var typing = textView.typingAttributes
        typing[.paragraphStyle] = style
        textView.typingAttributes = typing
    }
}

// MARK: - Rich Text Editing Session

@Observable
final class RichTextEditingSession {
    weak var textView: NSTextView?
    
    // Current selection state for toolbar updates
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isStrikethrough = false
    var currentHighlight: HighlightColor = .none
    var textColor: Color = .primary
    var pageInk: NSColor = .textColor
    private var colorPanelObserver: NSObjectProtocol?
    var isAdjustingPageColors = false
    var currentFontSize: CGFloat = 16
    var currentParagraphStyle: JournalParagraphStyle = .normal
    var currentLineSpacing: LineSpacing = .single
    var hasFirstLineIndent = false
    var isBulletList = false
    var isNumberedList = false
    var wordCount = 0
    var characterCount = 0
    var selectionWordCount: Int?
    var isEmpty = true
    
    /// Writes the document for the day that was open when editing started.
    /// Returns an error message, or nil when the day was saved.
    var persistHandler: ((NSAttributedString, Date) -> String?)?
    var savePhase: JournalSavePhase = .saved
    private var editGeneration = 0
    private var stagedDocument: NSAttributedString?
    private var stagedGeneration = 0
    private var appliedGeneration = 0
    /// Previous / next journal day (from Settings → Shortcuts).
    var onCommandArrowDay: ((Int) -> Void)?
    var previousDayChord: KeyChord = .journalPreviousDayDefault
    var nextDayChord: KeyChord = .journalNextDayDefault
    /// The day currently shown in the text view.
    var boundDate: Date?
    private var persistTimer: Timer?
    
    // Format painter
    var copiedAttributes: [NSAttributedString.Key: Any]?
    
    // Focus mode
    var isFocusModeEnabled = false
    
    func snapshot() -> NSAttributedString? {
        guard let storage = textView?.textStorage else { return nil }
        return NSAttributedString(attributedString: storage)
    }
    
    func cancelPendingPersist() {
        persistTimer?.invalidate()
        persistTimer = nil
    }
    
    /// Save the text view's current contents for `boundDate`.
    func persistNow() {
        cancelPendingPersist()
        guard let date = boundDate else { return }
        editGeneration += 1
        savePhase = .saving
        write(generation: editGeneration, date: date)
    }
    
    func schedulePersist() {
        updateSelectionState()
        if isAdjustingPageColors { return }
        guard let date = boundDate else { return }
        editGeneration += 1
        let generation = editGeneration
        savePhase = .saving
        cancelPendingPersist()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.write(generation: generation, date: date)
        }
    }
    
    private func write(generation: Int, date: Date) {
        guard let latest = snapshot() else {
            if editGeneration == generation { savePhase = .saved }
            return
        }
        let error = persistHandler?(latest, date)
        guard editGeneration == generation else { return }
        if let error {
            savePhase = .failed(error)
        } else {
            savePhase = .saved
        }
    }
    
    /// Replace the open document without writing it back over the previous day.
    func loadDocument(_ document: NSAttributedString) {
        persistTimer?.invalidate()
        persistTimer = nil
        stagedDocument = document
        stagedGeneration += 1
        applyStagedDocument()
    }
    
    /// Applies a staged day only when the text view exists and the day actually changed.
    func applyStagedDocument() {
        guard stagedGeneration != appliedGeneration,
              let stagedDocument,
              let textView,
              let storage = textView.textStorage else { return }
        appliedGeneration = stagedGeneration
        
        let content: NSAttributedString
        if stagedDocument.length == 0 {
            content = NSAttributedString(string: "", attributes: JournalRichText.defaultAttributes())
        } else {
            content = JournalTextLists.normalizeLegacyMarkers(stagedDocument)
        }
        
        storage.setAttributedString(content)
        recolorAutomaticBody(in: storage, ink: pageInk)
        var typing = JournalRichText.defaultAttributes()
        typing[.foregroundColor] = pageInk
        textView.typingAttributes = typing
        let end = storage.length
        textView.setSelectedRange(NSRange(location: min(end, storage.length), length: 0))
        updateSelectionState()
        textView.needsDisplay = true
        textView.window?.makeFirstResponder(textView)
        textView.updateInsertionPointStateAndRestartTimer(true)
        (textView as? JournalRichTextView)?.startSpellChecking()
    }
    
    func updateSelectionState() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let fullText = textStorage.string
        let words = fullText.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }
        wordCount = words.count
        characterCount = fullText.count
        isEmpty = words.isEmpty && !JournalTextLists.containsList(textStorage)
        
        let range = textView.selectedRange()
        if range.length > 0, NSMaxRange(range) <= textStorage.length {
            let selectedText = (fullText as NSString).substring(with: range)
            selectionWordCount = selectedText.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }.count
        } else {
            selectionWordCount = nil
        }
        
        guard textStorage.length > 0 else {
            isBold = false
            isItalic = false
            isUnderline = false
            isStrikethrough = false
            currentHighlight = .none
            currentFontSize = 16
            currentParagraphStyle = .normal
            isBulletList = false
            isNumberedList = false
            textColor = typingColor
            return
        }
        
        let checkLocation: Int
        if range.length > 0 {
            checkLocation = min(range.location, textStorage.length - 1)
        } else if range.location < textStorage.length {
            checkLocation = range.location
        } else {
            checkLocation = textStorage.length - 1
        }
        
        let attrs = textStorage.attributes(at: checkLocation, effectiveRange: nil)
        
        // Check font traits
        if let font = attrs[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            isBold = traits.contains(.boldFontMask)
            isItalic = traits.contains(.italicFontMask)
            currentFontSize = font.pointSize
            
            // Determine paragraph style from font
            let isSemibold = font.fontDescriptor.symbolicTraits.contains(.bold)
            if font.pointSize >= 32 && isSemibold { currentParagraphStyle = .title }
            else if font.pointSize >= 28 && isSemibold { currentParagraphStyle = .heading1 }
            else if font.pointSize >= 24 && isSemibold { currentParagraphStyle = .heading2 }
            else if font.pointSize >= 20 && isSemibold { currentParagraphStyle = .heading3 }
            else { currentParagraphStyle = .normal }
        }
        
        if let color = attrs[.foregroundColor] as? NSColor {
            textColor = Color(nsColor: color)
        } else {
            textColor = .primary
        }
        
        isUnderline = (attrs[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
        isStrikethrough = (attrs[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue
        
        // Check highlight
        if let bgColor = attrs[.backgroundColor] as? NSColor {
            if bgColor.isClose(to: .yellow.withAlphaComponent(0.4)) { currentHighlight = .yellow }
            else if bgColor.isClose(to: .green.withAlphaComponent(0.3)) { currentHighlight = .green }
            else if bgColor.isClose(to: .systemPink.withAlphaComponent(0.3)) { currentHighlight = .pink }
            else if bgColor.isClose(to: .systemBlue.withAlphaComponent(0.25)) { currentHighlight = .blue }
            else { currentHighlight = .none }
        } else {
            currentHighlight = .none
        }
        
        isBulletList = false
        isNumberedList = false
        if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
            let lists = paragraphStyle.textLists
            if lists.last?.isOrdered == true {
                isNumberedList = true
            } else if lists.last != nil {
                isBulletList = true
            }
            hasFirstLineIndent = paragraphStyle.firstLineHeadIndent > 20 && lists.isEmpty
            if paragraphStyle.headIndent > 0 && lists.isEmpty && currentParagraphStyle == .normal {
                currentParagraphStyle = .quote
            }
            let baseSize = max(currentFontSize, 1)
            let spacing = paragraphStyle.lineSpacing
            let ratio = spacing / baseSize
            if ratio >= 0.8 { currentLineSpacing = .double }
            else if ratio >= 0.4 { currentLineSpacing = .onePointFive }
            else if ratio >= 0.1 { currentLineSpacing = .onePointFifteen }
            else { currentLineSpacing = .single }
        }
    }
    
    // MARK: - Formatting Actions
    
    func toggleBold() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else {
            // Change typing attributes
            var attrs = textView.typingAttributes
            if let font = attrs[.font] as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isBold ? .unboldFontMask : .boldFontMask)
                attrs[.font] = newFont
                textView.typingAttributes = attrs
            }
            isBold.toggle()
            return
        }
        
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        textView.undoManager?.beginUndoGrouping()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isBold ? .unboldFontMask : .boldFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        textStorage.endEditing()
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func toggleItalic() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else {
            var attrs = textView.typingAttributes
            if let font = attrs[.font] as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isItalic ? .unitalicFontMask : .italicFontMask)
                attrs[.font] = newFont
                textView.typingAttributes = attrs
            }
            isItalic.toggle()
            return
        }
        
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        textView.undoManager?.beginUndoGrouping()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isItalic ? .unitalicFontMask : .italicFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        textStorage.endEditing()
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func toggleUnderline() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let newValue = isUnderline ? 0 : NSUnderlineStyle.single.rawValue
        
        guard range.length > 0 else {
            var attrs = textView.typingAttributes
            attrs[.underlineStyle] = newValue
            textView.typingAttributes = attrs
            isUnderline.toggle()
            return
        }
        
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttribute(.underlineStyle, value: newValue, range: range)
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func toggleStrikethrough() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let newValue = isStrikethrough ? 0 : NSUnderlineStyle.single.rawValue
        
        guard range.length > 0 else {
            var attrs = textView.typingAttributes
            attrs[.strikethroughStyle] = newValue
            textView.typingAttributes = attrs
            isStrikethrough.toggle()
            return
        }
        
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttribute(.strikethroughStyle, value: newValue, range: range)
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    /// Paints the page and keeps default body text readable on it. Chosen text colors stay put.
    func applyPage(paper: NSColor, ink: NSColor) {
        pageInk = ink
        JournalPageColors.ink = ink
        JournalPageColors.quoteInk = JournalPageColors.quoteInk(for: ink)
        
        guard let textView else { return }
        if let view = textView as? JournalRichTextView {
            view.pageBackground = paper
            view.pageInk = ink
            view.applyPageColors()
        } else {
            textView.backgroundColor = paper
            textView.insertionPointColor = ink
            textView.enclosingScrollView?.backgroundColor = paper
        }
        
        var typing = textView.typingAttributes
        if let current = typing[.foregroundColor] as? NSColor {
            if JournalPageColors.isAutomaticBody(current, ink: ink) {
                typing[.foregroundColor] = ink
            }
        } else {
            typing[.foregroundColor] = ink
        }
        textView.typingAttributes = typing
        
        if let storage = textView.textStorage, storage.length > 0 {
            recolorAutomaticBody(in: storage, ink: ink)
        }
        updateSelectionState()
    }
    
    private func recolorAutomaticBody(in storage: NSTextStorage, ink: NSColor) {
        isAdjustingPageColors = true
        textView?.undoManager?.disableUndoRegistration()
        storage.beginEditing()
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, subRange, _ in
            guard let color = value as? NSColor else { return }
            guard JournalPageColors.isAutomaticBody(color, ink: ink) else { return }
            if color.isClose(to: ink, tolerance: 0.02) { return }
            storage.addAttribute(.foregroundColor, value: ink, range: subRange)
        }
        storage.endEditing()
        textView?.undoManager?.enableUndoRegistration()
        isAdjustingPageColors = false
    }
    
    /// Applies color through `NSTextView.changeColor`, the same path as the system color panel.
    func setTextColor(_ color: NSColor) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        let panel = NSColorPanel.shared
        panel.color = color
        textView.changeColor(panel)
        updateSelectionState()
    }
    
    /// Live system color picker. Changes go to the text view while the panel is open.
    func showTextColorPanel() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let color = textView.typingAttributes[.foregroundColor] as? NSColor {
            panel.color = color
        }
        panel.setTarget(textView)
        panel.setAction(#selector(NSTextView.changeColor(_:)))
        panel.orderFront(nil)
        
        if colorPanelObserver == nil {
            let center = NotificationCenter.default
            colorPanelObserver = center.addObserver(
                forName: NSColorPanel.colorDidChangeNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                self?.updateSelectionState()
            }
            center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: panel,
                queue: .main
            ) { _ in
                panel.setTarget(nil)
            }
        }
    }
    
    private var typingColor: Color {
        guard let color = textView?.typingAttributes[.foregroundColor] as? NSColor else { return .primary }
        return Color(nsColor: color)
    }
    
    func setHighlight(_ highlight: HighlightColor) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        
        guard range.length > 0 else {
            var attrs = textView.typingAttributes
            if let color = highlight.color {
                attrs[.backgroundColor] = color
            } else {
                attrs.removeValue(forKey: .backgroundColor)
            }
            textView.typingAttributes = attrs
            currentHighlight = highlight
            return
        }
        
        textView.undoManager?.beginUndoGrouping()
        if let color = highlight.color {
            textStorage.addAttribute(.backgroundColor, value: color, range: range)
        } else {
            textStorage.removeAttribute(.backgroundColor, range: range)
        }
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func setFontSize(_ size: CGFloat) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        
        guard range.length > 0 else {
            var attrs = textView.typingAttributes
            if let font = attrs[.font] as? NSFont {
                attrs[.font] = NSFont(descriptor: font.fontDescriptor, size: size)
            }
            textView.typingAttributes = attrs
            currentFontSize = size
            return
        }
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFont(descriptor: font.fontDescriptor, size: size) ?? font
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func increaseFontSize() {
        let currentIndex = journalFontSizes.firstIndex(where: { $0 >= currentFontSize }) ?? 4
        let nextIndex = min(currentIndex + 1, journalFontSizes.count - 1)
        setFontSize(journalFontSizes[nextIndex])
    }
    
    func decreaseFontSize() {
        let currentIndex = journalFontSizes.firstIndex(where: { $0 >= currentFontSize }) ?? 4
        let prevIndex = max(currentIndex - 1, 0)
        setFontSize(journalFontSizes[prevIndex])
    }
    
    func setParagraphStyle(_ style: JournalParagraphStyle) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        
        // Expand to full paragraph
        range = ns.paragraphRange(for: range)
        guard range.length > 0 else { return }
        
        let template = style.paragraphStyle()
        textView.undoManager?.beginUndoGrouping()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subRange, _ in
            let paragraph = template.mutableCopy() as! NSMutableParagraphStyle
            if let existing = value as? NSParagraphStyle, !existing.textLists.isEmpty {
                paragraph.textLists = existing.textLists
                paragraph.headIndent = existing.headIndent
                paragraph.firstLineHeadIndent = existing.firstLineHeadIndent
            }
            var attributes = style.attributes()
            attributes[.paragraphStyle] = paragraph
            textStorage.addAttributes(attributes, range: subRange)
        }
        textStorage.endEditing()
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func setAlignment(_ alignment: NSTextAlignment) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        range = ns.paragraphRange(for: range)
        guard range.length > 0 else { return }
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subRange, _ in
            let newStyle = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            newStyle.alignment = alignment
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: subRange)
        }
        textView.undoManager?.endUndoGrouping()
    }
    
    func setLineSpacing(_ spacing: LineSpacing) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        range = ns.paragraphRange(for: range)
        guard range.length > 0 else { return }
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttributes(in: range, options: []) { attrs, subRange, _ in
            let font = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 16)
            let newStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            newStyle.lineSpacing = font.pointSize * CGFloat(spacing.rawValue - 1)
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: subRange)
        }
        textView.undoManager?.endUndoGrouping()
        currentLineSpacing = spacing
    }
    
    func toggleFirstLineIndent() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        range = ns.paragraphRange(for: range)
        guard range.length > 0 else { return }
        
        let newIndent: CGFloat = hasFirstLineIndent ? 0 : 32
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subRange, _ in
            let newStyle = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            newStyle.firstLineHeadIndent = newIndent
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: subRange)
        }
        textView.undoManager?.endUndoGrouping()
        hasFirstLineIndent = !hasFirstLineIndent
    }
    
    func toggleBulletList() {
        guard let textView else { return }
        JournalTextLists.toggle(JournalTextLists.bulletMarker, in: textView)
        updateSelectionState()
    }
    
    func toggleNumberedList() {
        guard let textView else { return }
        JournalTextLists.toggle(JournalTextLists.numberedMarker, in: textView)
        updateSelectionState()
    }
    
    func insertLink() {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selectedText = range.length > 0 ? (textView.string as NSString).substring(with: range) : "link"
        
        // Show link dialog
        let alert = NSAlert()
        alert.messageText = "Insert Link"
        alert.informativeText = "Enter the URL:"
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = "https://"
        alert.accessoryView = input
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let urlString = input.stringValue
        guard let url = URL(string: urlString) else { return }
        
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .link: url,
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        textView.undoManager?.beginUndoGrouping()
        if range.length > 0 {
            textView.textStorage?.addAttributes(linkAttrs, range: range)
        } else {
            let linkString = NSAttributedString(string: selectedText, attributes: linkAttrs)
            textView.textStorage?.insert(linkString, at: range.location)
        }
        textView.undoManager?.endUndoGrouping()
    }
    
    func clearFormatting() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.setAttributes(JournalRichText.defaultAttributes(), range: range)
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
    }
    
    func insertDateTimestamp() {
        guard let textView else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        let timestamp = formatter.string(from: Date())
        
        let range = textView.selectedRange()
        textView.undoManager?.beginUndoGrouping()
        textView.textStorage?.replaceCharacters(in: range, with: timestamp)
        textView.undoManager?.endUndoGrouping()
    }
    
    /// Appends a block at the end of the page so existing writing stays put.
    func insertTaskTemplate(_ template: NSAttributedString) {
        guard let textView, let storage = textView.textStorage else { return }
        let block = NSMutableAttributedString()
        if storage.length > 0 {
            block.append(NSAttributedString(string: "\n", attributes: JournalRichText.defaultAttributes()))
        }
        block.append(template)
        let range = NSRange(location: storage.length, length: 0)
        textView.undoManager?.beginUndoGrouping()
        if textView.shouldChangeText(in: range, replacementString: block.string) {
            storage.replaceCharacters(in: range, with: block)
            textView.didChangeText()
            let end = NSRange(location: storage.length, length: 0)
            textView.setSelectedRange(end)
            textView.scrollRangeToVisible(end)
        }
        textView.undoManager?.endUndoGrouping()
        isEmpty = storage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func insertSceneBreak() {
        guard let textView else { return }
        let range = textView.selectedRange()
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 16
        style.paragraphSpacingBefore = 16
        
        let breakString = NSAttributedString(string: "\n* * *\n", attributes: [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ])
        
        textView.undoManager?.beginUndoGrouping()
        textView.textStorage?.insert(breakString, at: range.location)
        textView.undoManager?.endUndoGrouping()
    }
    
    func insertHorizontalRule() {
        guard let textView else { return }
        let range = textView.selectedRange()
        
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 12
        style.paragraphSpacingBefore = 12
        
        let ruleString = NSAttributedString(string: "\n───────────────────────\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.separatorColor,
            .paragraphStyle: style
        ])
        
        textView.undoManager?.beginUndoGrouping()
        textView.textStorage?.insert(ruleString, at: range.location)
        textView.undoManager?.endUndoGrouping()
    }
    
    func insertFootnote() {
        guard let textView, let textStorage = textView.textStorage else { return }
        
        // Count existing footnotes
        let text = textStorage.string
        let footnotePattern = #"\[\^(\d+)\]"#
        let regex = try? NSRegularExpression(pattern: footnotePattern, options: [])
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
        let nextNumber = matches.count + 1
        
        let range = textView.selectedRange()
        
        // Insert superscript reference
        let refAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .baselineOffset: 6,
            .foregroundColor: NSColor.systemBlue
        ]
        let refString = NSAttributedString(string: "[\(nextNumber)]", attributes: refAttrs)
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.insert(refString, at: range.location)
        
        // Add footnote at end of document
        let noteStyle = NSMutableParagraphStyle()
        noteStyle.paragraphSpacing = 4
        noteStyle.firstLineHeadIndent = 0
        noteStyle.headIndent = 20
        
        // Check if Notes section exists
        let notesHeader = "\n\n---\nNotes:\n"
        let noteText = "[\(nextNumber)] "
        
        if !text.contains("---\nNotes:") {
            let headerString = NSAttributedString(string: notesHeader, attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            textStorage.append(headerString)
        }
        
        let noteString = NSAttributedString(string: noteText + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: noteStyle
        ])
        textStorage.append(noteString)
        
        textView.undoManager?.endUndoGrouping()
        
        // Move cursor to footnote area
        textView.setSelectedRange(NSRange(location: textStorage.length - 1, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    
    func copyFormat() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.location < textStorage.length else { return }
        
        let location = range.length > 0 ? range.location : max(0, range.location - 1)
        copiedAttributes = textStorage.attributes(at: location, effectiveRange: nil)
    }
    
    func pasteFormat() {
        guard let textView, let textStorage = textView.textStorage,
              let attrs = copiedAttributes else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttributes(attrs, range: range)
        textView.undoManager?.endUndoGrouping()
        
        // Clear after single use
        copiedAttributes = nil
        updateSelectionState()
    }
    
    func toggleFocusMode() {
        isFocusModeEnabled.toggle()
        applyFocusMode()
    }
    
    func applyFocusMode() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        if isFocusModeEnabled {
            // Get current paragraph
            let ns = textStorage.string as NSString
            let cursorLocation = textView.selectedRange().location
            let paragraphRange = ns.paragraphRange(for: NSRange(location: cursorLocation, length: 0))
            
            // Dim all text
            textStorage.addAttribute(.foregroundColor, value: pageInk.withAlphaComponent(0.35), range: fullRange)
            
            // Restore current paragraph
            textStorage.enumerateAttribute(.foregroundColor, in: paragraphRange, options: []) { _, subRange, _ in
                textStorage.addAttribute(.foregroundColor, value: pageInk, range: subRange)
            }
            
            // Scroll to keep current paragraph visible
            textView.scrollRangeToVisible(paragraphRange)
        } else {
            // Restore all text colors
            textStorage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, subRange, _ in
                if let color = value as? NSColor, color.alphaComponent < 1 {
                    textStorage.addAttribute(.foregroundColor, value: pageInk, range: subRange)
                }
            }
        }
    }
}

// MARK: - Modern Rich Text Toolbar

struct RichTextToolbar: View {
    @Bindable var session: RichTextEditingSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoverTip: String?
    
    private var chipFill: Color {
        Color.primary.opacity(colorScheme == .light ? 0.08 : 0.05)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Undo/Redo
                HStack(spacing: 1) {
                    toolButton("arrow.uturn.backward", help: "Undo (⌘Z)") {
                        session.textView?.undoManager?.undo()
                    }
                    toolButton("arrow.uturn.forward", help: "Redo (⌘⇧Z)") {
                        session.textView?.undoManager?.redo()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Paragraph style picker
                Menu {
                    ForEach(JournalParagraphStyle.allCases) { style in
                        Button(style.rawValue) {
                            session.setParagraphStyle(style)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(session.currentParagraphStyle.rawValue)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .frame(width: 80)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Paragraph style" : (hoverTip == "Paragraph style" ? nil : hoverTip)
                }
                .help("Paragraph style")
                
                // Font size picker
                Menu {
                    ForEach(journalFontSizes, id: \.self) { size in
                        Button("\(Int(size)) pt") {
                            session.setFontSize(size)
                        }
                    }
                    Divider()
                    Button("Larger (⌘⇧.)") { session.increaseFontSize() }
                    Button("Smaller (⌘⇧,)") { session.decreaseFontSize() }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(Int(session.currentFontSize))")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .frame(width: 40)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Font size" : (hoverTip == "Font size" ? nil : hoverTip)
                }
                .help("Font size")
                
                Divider().frame(height: 20)
                
                // Text formatting group
                HStack(spacing: 1) {
                    formatButton("bold", help: "Bold (⌘B)", isActive: session.isBold) { session.toggleBold() }
                    formatButton("italic", help: "Italic (⌘I)", isActive: session.isItalic) { session.toggleItalic() }
                    formatButton("underline", help: "Underline (⌘U)", isActive: session.isUnderline) { session.toggleUnderline() }
                    formatButton("strikethrough", help: "Strikethrough (⌘⇧X)", isActive: session.isStrikethrough) { session.toggleStrikethrough() }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Menu {
                    ForEach(JournalTextColor.allCases) { choice in
                        Button {
                            let color = choice == .automatic ? session.pageInk : choice.nsColor
                            session.setTextColor(color)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(choice == .automatic ? Color(nsColor: session.pageInk) : choice.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(choice.rawValue)
                            }
                        }
                    }
                    Divider()
                    Button("Choose Color…") {
                        session.showTextColorPanel()
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text("A")
                            .font(.system(size: 13, weight: .semibold))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(session.textColor)
                            .frame(width: 14, height: 3)
                    }
                    .foregroundStyle(Color.primary)
                    .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Text Color" : (hoverTip == "Text Color" ? nil : hoverTip)
                }
                .help("Text Color")
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                // Highlight colors
                Menu {
                    ForEach(HighlightColor.allCases) { color in
                        Button {
                            session.setHighlight(color)
                        } label: {
                            HStack {
                                if color != .none {
                                    Circle()
                                        .fill(color.swiftUIColor.opacity(0.6))
                                        .frame(width: 12, height: 12)
                                }
                                Text(color.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "highlighter")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(session.currentHighlight == .none ? Color.primary : session.currentHighlight.swiftUIColor)
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Highlight (⌘⇧H)" : (hoverTip == "Highlight (⌘⇧H)" ? nil : hoverTip)
                }
                .help("Highlight (⌘⇧H)")
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(session.currentHighlight == .none ? chipFill : session.currentHighlight.swiftUIColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Alignment
                HStack(spacing: 1) {
                    toolButton("text.alignleft", help: "Align Left") { session.setAlignment(.left) }
                    toolButton("text.aligncenter", help: "Center") { session.setAlignment(.center) }
                    toolButton("text.alignright", help: "Align Right") { session.setAlignment(.right) }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Lists
                HStack(spacing: 1) {
                    formatButton("list.bullet", help: "Bullet List (⌘⇧8)", isActive: session.isBulletList) { session.toggleBulletList() }
                    formatButton("list.number", help: "Numbered List (⌘⇧7)", isActive: session.isNumberedList) { session.toggleNumberedList() }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                // Line spacing
                Menu {
                    ForEach(LineSpacing.allCases) { spacing in
                        Button(spacing.label) {
                            session.setLineSpacing(spacing)
                        }
                    }
                    Divider()
                    Button {
                        session.toggleFirstLineIndent()
                    } label: {
                        HStack {
                            Text("First Line Indent")
                            if session.hasFirstLineIndent {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "text.linesspacing")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Line spacing" : (hoverTip == "Line spacing" ? nil : hoverTip)
                }
                .help("Line spacing")
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Insert group
                Menu {
                    Button("Link (⌘K)") { session.insertLink() }
                    Button("Date & Time (⌘;)") { session.insertDateTimestamp() }
                    Divider()
                    Button("Scene Break (* * *)") { session.insertSceneBreak() }
                    Button("Horizontal Rule") { session.insertHorizontalRule() }
                    Button("Footnote") { session.insertFootnote() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Insert")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoverTip = hovering ? "Insert" : (hoverTip == "Insert" ? nil : hoverTip)
                }
                .help("Insert")
                
                Divider().frame(height: 20)
                
                // Format painter
                HStack(spacing: 1) {
                    formatButton("paintbrush", help: "Copy Format (⌘⌥C)", isActive: session.copiedAttributes != nil) {
                        if session.copiedAttributes != nil {
                            session.pasteFormat()
                        } else {
                            session.copyFormat()
                        }
                    }
                    toolButton("clear", help: "Clear Formatting") { session.clearFormatting() }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                toolButton("textformat.abc", help: "Spelling") {
                    session.textView?.showGuessPanel(nil)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                formatButton("eye", help: "Focus Mode (⌘⇧F)", isActive: session.isFocusModeEnabled) {
                    session.toggleFocusMode()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(session.isFocusModeEnabled ? Color.orange.opacity(0.2) : chipFill, in: RoundedRectangle(cornerRadius: 6))
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 40)
        .overlay(alignment: .top) {
            if let hoverTip {
                Text(hoverTip)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    .offset(y: 42)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(hoverTip == nil ? 0 : 4)
    }
    
    private func toolButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoverTip = hovering ? help : (hoverTip == help ? nil : hoverTip)
        }
        .help(help)
    }
    
    private func formatButton(_ systemName: String, help: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.orange : Color.primary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isActive ? Color.orange.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            hoverTip = hovering ? help : (hoverTip == help ? nil : hoverTip)
        }
        .help(help)
    }
    
}

// MARK: - Rich Text Editor (NSTextView wrapper)

struct RichTextEditor: NSViewRepresentable {
    var session: RichTextEditingSession
    var paper: NSColor
    var ink: NSColor
    
    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = JournalScrollView()
        scroll.contentView = JournalClipView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = paper
        scroll.borderType = .noBorder
        // TextKit 2 draws NSTextList markers and continues them on Return.
        // The TextKit 1 initializer leaves the markers out of the layout.
        let textView = JournalRichTextView(usingTextLayoutManager: true)
        textView.session = session
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.pageBackground = paper
        textView.pageInk = ink
        textView.backgroundColor = paper
        textView.insertionPointColor = ink
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 48, height: 36)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.defaultParagraphStyle = JournalParagraphStyle.normal.paragraphStyle()
        textView.typingAttributes = JournalRichText.defaultAttributes()
        textView.textStorage?.setAttributedString(JournalRichText.defaultAttributedString())
        
        scroll.documentView = textView
        session.textView = textView
        session.applyStagedDocument()
        session.applyPage(paper: paper, ink: ink)
        textView.startSpellChecking()
        
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? JournalRichTextView else { return }
        textView.session = session
        session.textView = textView
        context.coordinator.session = session
        session.applyStagedDocument()
        if !context.coordinator.appliedPaper.isClose(to: paper, tolerance: 0.01)
            || !context.coordinator.appliedInk.isClose(to: ink, tolerance: 0.01) {
            context.coordinator.appliedPaper = paper
            context.coordinator.appliedInk = ink
            session.applyPage(paper: paper, ink: ink)
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var session: RichTextEditingSession
        var appliedPaper: NSColor = .clear
        var appliedInk: NSColor = .clear
        
        init(session: RichTextEditingSession) {
            self.session = session
        }
        
        func textDidChange(_ notification: Notification) {
            session.schedulePersist()
            if session.isFocusModeEnabled {
                session.applyFocusMode()
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            session.updateSelectionState()
            if session.isFocusModeEnabled {
                session.applyFocusMode()
            }
        }
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}

private final class JournalScrollView: NSScrollView {
    override var wantsLayer: Bool {
        get { false }
        set { }
    }
}

private final class JournalClipView: NSClipView {
    override var wantsLayer: Bool {
        get { false }
        set { }
    }
}

private final class JournalRichTextView: NSTextView {
    weak var session: RichTextEditingSession?
    var pageBackground: NSColor = JournalPageColors.warm
    var pageInk: NSColor = JournalPageColors.lightInk
    private var appliedInset: CGFloat = -1
    private var viewportObservers: [NSObjectProtocol] = []
    
    /// SwiftUI turns layers on after updates. A layer-backed text view stops flashing the caret.
    override var wantsLayer: Bool {
        get { false }
        set { }
    }
    
    override var wantsUpdateLayer: Bool { false }
    
    deinit {
        removeViewportObservers()
    }
    
    /// Underlines misspellings and offers suggestions from the system dictionary.
    func startSpellChecking() {
        isGrammarCheckingEnabled = true
        isContinuousSpellCheckingEnabled = true
        isAutomaticSpellingCorrectionEnabled = false
        enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.spelling.rawValue
            | NSTextCheckingResult.CheckingType.grammar.rawValue
        guard let storage = textStorage, storage.length > 0, window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.checkTextInDocument(nil)
        }
    }
    
    func applyPageColors() {
        drawsBackground = true
        backgroundColor = pageBackground
        insertionPointColor = pageInk
        enclosingScrollView?.drawsBackground = true
        enclosingScrollView?.backgroundColor = pageBackground
        enclosingScrollView?.contentView.drawsBackground = true
        enclosingScrollView?.contentView.backgroundColor = pageBackground
    }
    
    /// Keep a 680pt writing column centered in the window.
    func centerWritingColumn() {
        guard let viewport = enclosingScrollView?.contentSize.width, viewport > 1 else { return }
        let side = max(48, floor((viewport - 680) / 2))
        guard abs(side - appliedInset) > 0.5 else { return }
        appliedInset = side
        textContainerInset = NSSize(width: side, height: 36)
        textContainer?.widthTracksTextView = true
        needsDisplay = true
    }
    
    /// Full screen and live resize finish with a stale line layout unless this runs.
    /// Stay on `textLayoutManager`. Reading `layoutManager` switches the view back to TextKit 1.
    func relayoutForViewportChange() {
        centerWritingColumn()
        if let layoutManager = textLayoutManager {
            layoutManager.ensureLayout(for: layoutManager.documentRange)
        }
        needsDisplay = true
        if window?.firstResponder === self {
            updateInsertionPointStateAndRestartTimer(true)
        }
    }
    
    override func layout() {
        super.layout()
        if window?.inLiveResize == true { return }
        centerWritingColumn()
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        relayoutAfterViewportSettles()
    }
    
    /// The final bounds are sometimes one turn behind the notification.
    private func relayoutAfterViewportSettles() {
        relayoutForViewportChange()
        DispatchQueue.main.async { [weak self] in
            self?.relayoutForViewportChange()
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeViewportObservers()
        guard let window else { return }
        applyPageColors()
        startSpellChecking()
        let center = NotificationCenter.default
        viewportObservers = [
            center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                self?.relayoutAfterViewportSettles()
            },
            center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { [weak self] _ in
                self?.relayoutAfterViewportSettles()
            }
        ]
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            self.window?.makeFirstResponder(self)
            self.updateInsertionPointStateAndRestartTimer(true)
        }
    }
    
    private func removeViewportObservers() {
        for token in viewportObservers {
            NotificationCenter.default.removeObserver(token)
        }
        viewportObservers.removeAll()
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if performFormattingShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    /// Matches physical keys. `charactersIgnoringModifiers` still includes Shift,
    /// so ⌘⇧8 arrives as "*" and the old character switch never saw a list shortcut.
    private func performFormattingShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command), !flags.contains(.control) else { return false }
        
        let action: (() -> Void)?
        switch Int(event.keyCode) {
        case kVK_ANSI_B where flags == .command:
            action = { [weak self] in self?.session?.toggleBold() }
        case kVK_ANSI_I where flags == .command:
            action = { [weak self] in self?.session?.toggleItalic() }
        case kVK_ANSI_U where flags == .command:
            action = { [weak self] in self?.session?.toggleUnderline() }
        case kVK_ANSI_K where flags == .command:
            action = { [weak self] in self?.session?.insertLink() }
        case kVK_ANSI_Semicolon where flags == .command:
            action = { [weak self] in self?.session?.insertDateTimestamp() }
        case kVK_ANSI_X where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.toggleStrikethrough() }
        case kVK_ANSI_H where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.setHighlight(.yellow) }
        case kVK_ANSI_7 where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.toggleNumberedList() }
        case kVK_ANSI_8 where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.toggleBulletList() }
        case kVK_ANSI_Period where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.increaseFontSize() }
        case kVK_ANSI_Comma where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.decreaseFontSize() }
        case kVK_ANSI_F where flags == [.command, .shift]:
            action = { [weak self] in self?.session?.toggleFocusMode() }
        case kVK_ANSI_0 where flags == [.command, .option]:
            action = { [weak self] in self?.session?.setParagraphStyle(.normal) }
        case kVK_ANSI_1 where flags == [.command, .option]:
            action = { [weak self] in self?.session?.setParagraphStyle(.heading1) }
        case kVK_ANSI_2 where flags == [.command, .option]:
            action = { [weak self] in self?.session?.setParagraphStyle(.heading2) }
        case kVK_ANSI_3 where flags == [.command, .option]:
            action = { [weak self] in self?.session?.setParagraphStyle(.heading3) }
        case kVK_ANSI_C where flags == [.command, .option]:
            action = { [weak self] in self?.session?.copyFormat() }
        case kVK_ANSI_V where flags == [.command, .option]:
            action = { [weak self] in self?.session?.pasteFormat() }
        default:
            action = nil
        }
        guard let action else { return false }
        // Return before the action so ⌘Z, ⌘W, and the menus still receive every other key.
        DispatchQueue.main.async(execute: action)
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            updateInsertionPointStateAndRestartTimer(true)
        }
        return result
    }
}

// MARK: - Color Comparison Helper

extension NSColor {
    func isClose(to other: NSColor, tolerance: CGFloat = 0.1) -> Bool {
        guard let selfRGB = usingColorSpace(.sRGB),
              let otherRGB = other.usingColorSpace(.sRGB) else { return false }
        
        return abs(selfRGB.redComponent - otherRGB.redComponent) < tolerance &&
               abs(selfRGB.greenComponent - otherRGB.greenComponent) < tolerance &&
               abs(selfRGB.blueComponent - otherRGB.blueComponent) < tolerance &&
               abs(selfRGB.alphaComponent - otherRGB.alphaComponent) < tolerance
    }
}
