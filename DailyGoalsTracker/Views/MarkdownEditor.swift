import AppKit
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
        case .quote: return .secondaryLabelColor
        default: return .textColor
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
        
        for (index, line) in lines.enumerated() {
            var processedLine = line
            var style = JournalParagraphStyle.normal
            
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
            // Handle bullet lists - convert to bullet character
            else if let match = processedLine.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
                processedLine = "• " + String(processedLine[match.upperBound...])
            }
            
            let lineAttr = NSMutableAttributedString(string: processedLine, attributes: style.attributes())
            
            // Apply inline formatting
            applyInlineFormatting(to: lineAttr, baseFont: style.font())
            
            result.append(lineAttr)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: style.attributes()))
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
                
                if let font = attrs[.font] as? NSFont {
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
                
                if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                    if paragraphStyle.headIndent > 0 {
                        mdLine = "> "
                    }
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
    var currentFontSize: CGFloat = 16
    var currentParagraphStyle: JournalParagraphStyle = .normal
    var currentLineSpacing: LineSpacing = .single
    var hasFirstLineIndent = false
    var wordCount = 0
    var characterCount = 0
    var selectionWordCount: Int?
    var isEmpty = true
    
    /// Updates the in-memory document immediately. Disk writes stay debounced.
    var onLiveUpdate: ((NSAttributedString) -> Void)?
    /// Writes the document to storage for the day that was open when editing started.
    var persistHandler: ((NSAttributedString, Date) -> Void)?
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
        guard let snap = snapshot(), let date = boundDate else { return }
        onLiveUpdate?(snap)
        persistHandler?(snap, date)
    }
    
    func schedulePersist() {
        updateSelectionState()
        guard let snap = snapshot(), let date = boundDate else { return }
        onLiveUpdate?(snap)
        cancelPendingPersist()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self, let latest = self.snapshot() else { return }
            self.persistHandler?(latest, date)
        }
    }
    
    /// Replace the open document without writing it back over the previous day.
    func loadDocument(_ document: NSAttributedString) {
        persistTimer?.invalidate()
        persistTimer = nil
        guard let textView, let storage = textView.textStorage else { return }
        
        let content: NSAttributedString
        if document.length == 0 {
            content = NSAttributedString(string: "", attributes: JournalRichText.defaultAttributes())
        } else {
            content = document
        }
        
        storage.setAttributedString(content)
        textView.typingAttributes = JournalRichText.defaultAttributes()
        let end = (storage.string as NSString).length
        textView.setSelectedRange(NSRange(location: min(end, storage.length), length: 0))
        updateSelectionState()
        textView.needsDisplay = true
        textView.window?.makeFirstResponder(textView)
        textView.updateInsertionPointStateAndRestartTimer(true)
    }
    
    func updateSelectionState() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let fullText = textStorage.string
        let words = fullText.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }
        wordCount = words.count
        characterCount = fullText.count
        isEmpty = words.isEmpty
        
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
            return
        }
        
        let checkLocation: Int
        if range.length > 0 {
            checkLocation = min(range.location, textStorage.length - 1)
        } else {
            checkLocation = min(max(0, range.location - 1), textStorage.length - 1)
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
        
        // Check paragraph style
        if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
            hasFirstLineIndent = paragraphStyle.firstLineHeadIndent > 20
            if paragraphStyle.headIndent > 0 && currentParagraphStyle == .normal {
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
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isBold ? .unboldFontMask : .boldFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
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
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toHaveTrait: isItalic ? .unitalicFontMask : .italicFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
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
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttribute(.underlineStyle, value: newValue, range: range)
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
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttribute(.strikethroughStyle, value: newValue, range: range)
        textView.undoManager?.endUndoGrouping()
        updateSelectionState()
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
        
        textView.undoManager?.beginUndoGrouping()
        textStorage.addAttributes(style.attributes(), range: range)
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
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        range = ns.paragraphRange(for: range)
        let paragraph = ns.substring(with: range)
        
        textView.undoManager?.beginUndoGrouping()
        
        if paragraph.hasPrefix("• ") || paragraph.hasPrefix("- ") {
            // Remove bullet
            let newText = String(paragraph.dropFirst(2))
            textStorage.replaceCharacters(in: range, with: newText)
        } else if paragraph.first?.isNumber == true, let dotIndex = paragraph.firstIndex(of: ".") {
            // Replace number with bullet
            let afterDot = paragraph.index(after: dotIndex)
            if afterDot < paragraph.endIndex && paragraph[afterDot] == " " {
                let content = String(paragraph[paragraph.index(after: afterDot)...])
                textStorage.replaceCharacters(in: range, with: "• " + content)
            }
        } else {
            // Add bullet
            textStorage.replaceCharacters(in: NSRange(location: range.location, length: 0), with: "• ")
        }
        
        textView.undoManager?.endUndoGrouping()
    }
    
    func toggleNumberedList() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let ns = textStorage.string as NSString
        var range = textView.selectedRange()
        range = ns.paragraphRange(for: range)
        let paragraph = ns.substring(with: range)
        
        textView.undoManager?.beginUndoGrouping()
        
        if paragraph.first?.isNumber == true, let dotIndex = paragraph.firstIndex(of: ".") {
            // Remove number
            let afterDot = paragraph.index(after: dotIndex)
            if afterDot < paragraph.endIndex && paragraph[afterDot] == " " {
                let content = String(paragraph[paragraph.index(after: afterDot)...])
                textStorage.replaceCharacters(in: range, with: content)
            }
        } else if paragraph.hasPrefix("• ") || paragraph.hasPrefix("- ") {
            // Replace bullet with number
            let content = String(paragraph.dropFirst(2))
            textStorage.replaceCharacters(in: range, with: "1. " + content)
        } else {
            // Add number
            textStorage.replaceCharacters(in: NSRange(location: range.location, length: 0), with: "1. ")
        }
        
        textView.undoManager?.endUndoGrouping()
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
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor.withAlphaComponent(0.3), range: fullRange)
            
            // Restore current paragraph
            textStorage.enumerateAttribute(.foregroundColor, in: paragraphRange, options: []) { _, subRange, _ in
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: subRange)
            }
            
            // Scroll to keep current paragraph visible
            textView.scrollRangeToVisible(paragraphRange)
        } else {
            // Restore all text colors
            textStorage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, subRange, _ in
                if let color = value as? NSColor, color.alphaComponent < 1 {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: subRange)
                }
            }
        }
        textView.updateInsertionPointStateAndRestartTimer(true)
    }
}

// MARK: - Modern Rich Text Toolbar

struct RichTextToolbar: View {
    @Bindable var session: RichTextEditingSession
    @State private var hoverTip: String?
    
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
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
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
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
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
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
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
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
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
                .background(session.currentHighlight == .none ? Color.primary.opacity(0.04) : session.currentHighlight.swiftUIColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Alignment
                HStack(spacing: 1) {
                    toolButton("text.alignleft", help: "Align Left") { session.setAlignment(.left) }
                    toolButton("text.aligncenter", help: "Center") { session.setAlignment(.center) }
                    toolButton("text.alignright", help: "Align Right") { session.setAlignment(.right) }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Lists
                HStack(spacing: 1) {
                    toolButton("list.bullet", help: "Bullet List (⌘⇧8)") { session.toggleBulletList() }
                    toolButton("list.number", help: "Numbered List (⌘⇧7)") { session.toggleNumberedList() }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
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
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
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
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
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
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
                Divider().frame(height: 20)
                
                // Focus mode
                formatButton("eye", help: "Focus Mode (⌘⇧F)", isActive: session.isFocusModeEnabled) {
                    session.toggleFocusMode()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(session.isFocusModeEnabled ? Color.orange.opacity(0.2) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                
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
    var document: NSAttributedString
    
    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.borderType = .noBorder
        let textView = JournalRichTextView()
        textView.session = session
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isGrammarCheckingEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
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
        textView.textStorage?.setAttributedString(document)
        
        scroll.documentView = textView
        session.textView = textView
        
        DispatchQueue.main.async {
            guard textView.window != nil else { return }
            textView.window?.makeFirstResponder(textView)
            textView.updateInsertionPointStateAndRestartTimer(true)
            session.updateSelectionState()
        }
        
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? JournalRichTextView else { return }
        textView.session = session
        session.textView = textView
        context.coordinator.session = session
        textView.centerWritingColumn()
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var session: RichTextEditingSession
        
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

private final class JournalRichTextView: NSTextView {
    weak var session: RichTextEditingSession?
    private var appliedInset: CGFloat = -1
    
    /// Keep a 680pt writing column centered in the window.
    func centerWritingColumn() {
        guard let viewport = enclosingScrollView?.contentSize.width, viewport > 1 else { return }
        let side = max(48, floor((viewport - 680) / 2))
        guard abs(side - appliedInset) > 0.5 else { return }
        appliedInset = side
        textContainerInset = NSSize(width: side, height: 36)
        textContainer?.widthTracksTextView = true
    }
    
    override func layout() {
        super.layout()
        centerWritingColumn()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        // A layer-backed text view, or one that does not draw its background,
        // never flashes the insertion point. SwiftUI turns layers on, so turn them back off.
        wantsLayer = false
        enclosingScrollView?.wantsLayer = false
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        insertionPointColor = .textColor
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            self.window?.makeFirstResponder(self)
            self.updateInsertionPointStateAndRestartTimer(true)
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        
        let chars = event.charactersIgnoringModifiers ?? ""
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        
        switch chars.lowercased() {
        case "b" where !shift && !option:
            session?.toggleBold()
            return true
        case "i" where !shift && !option:
            session?.toggleItalic()
            return true
        case "u" where !shift && !option:
            session?.toggleUnderline()
            return true
        case "x" where shift && !option:
            session?.toggleStrikethrough()
            return true
        case "h" where shift && !option:
            session?.setHighlight(.yellow)
            return true
        case "k" where !shift && !option:
            session?.insertLink()
            return true
        case ";" where !shift && !option:
            session?.insertDateTimestamp()
            return true
        case "0" where option && !shift:
            session?.setParagraphStyle(.normal)
            return true
        case "1" where option && !shift:
            session?.setParagraphStyle(.heading1)
            return true
        case "2" where option && !shift:
            session?.setParagraphStyle(.heading2)
            return true
        case "3" where option && !shift:
            session?.setParagraphStyle(.heading3)
            return true
        case "7" where shift && !option:
            session?.toggleNumberedList()
            return true
        case "8" where shift && !option:
            session?.toggleBulletList()
            return true
        case "." where shift && !option:
            session?.increaseFontSize()
            return true
        case "," where shift && !option:
            session?.decreaseFontSize()
            return true
        case "c" where option && !shift:
            session?.copyFormat()
            return true
        case "v" where option && !shift:
            session?.pasteFormat()
            return true
        case "f" where shift && !option:
            session?.toggleFocusMode()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
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
