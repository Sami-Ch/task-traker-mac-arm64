import AppKit
import SwiftUI

// MARK: - Markdown Helpers

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
    
    /// Returns an NSAttributedString for the rendered preview.
    static func attributedString(_ source: String, fontSize: CGFloat = 15) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        
        let baseFont = NSFont.systemFont(ofSize: fontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let monoFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
        
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let lines = source.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            var processedLine = line
            var lineAttrs = baseAttrs
            
            // Handle headings
            if let match = processedLine.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                let level = processedLine[match].filter { $0 == "#" }.count
                processedLine = String(processedLine[match.upperBound...])
                let size = fontSize + CGFloat(7 - level) * 2
                lineAttrs[.font] = NSFont.systemFont(ofSize: size, weight: level == 1 ? .bold : .semibold)
            }
            // Handle blockquotes
            else if processedLine.hasPrefix("> ") {
                processedLine = String(processedLine.dropFirst(2))
                lineAttrs[.foregroundColor] = NSColor.secondaryLabelColor
                let quoteParagraph = NSMutableParagraphStyle()
                quoteParagraph.lineSpacing = 4
                quoteParagraph.paragraphSpacing = 8
                quoteParagraph.headIndent = 16
                quoteParagraph.firstLineHeadIndent = 16
                lineAttrs[.paragraphStyle] = quoteParagraph
            }
            // Handle bullet lists
            else if let match = processedLine.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
                processedLine = "• " + String(processedLine[match.upperBound...])
                let listParagraph = NSMutableParagraphStyle()
                listParagraph.lineSpacing = 4
                listParagraph.paragraphSpacing = 4
                listParagraph.headIndent = 20
                listParagraph.firstLineHeadIndent = 8
                lineAttrs[.paragraphStyle] = listParagraph
            }
            // Handle numbered lists
            else if let match = processedLine.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                let numMatch = processedLine[match]
                let num = numMatch.filter { $0.isNumber }
                processedLine = "\(num). " + String(processedLine[match.upperBound...])
                let listParagraph = NSMutableParagraphStyle()
                listParagraph.lineSpacing = 4
                listParagraph.paragraphSpacing = 4
                listParagraph.headIndent = 24
                listParagraph.firstLineHeadIndent = 8
                lineAttrs[.paragraphStyle] = listParagraph
            }
            // Handle horizontal rules
            else if processedLine.trimmingCharacters(in: .whitespaces) == "---" {
                let divider = NSMutableAttributedString(string: "\n")
                divider.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: 1))
                divider.addAttribute(.strikethroughColor, value: NSColor.separatorColor, range: NSRange(location: 0, length: 1))
                result.append(divider)
                if index < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
                }
                continue
            }
            
            // Now process inline formatting
            let lineString = NSMutableAttributedString(string: processedLine, attributes: lineAttrs)
            
            // Apply inline formatting
            applyInlineFormatting(lineString, boldFont: boldFont, italicFont: italicFont, monoFont: monoFont)
            
            result.append(lineString)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
            }
        }
        
        return result
    }
    
    private static func applyInlineFormatting(_ attrString: NSMutableAttributedString, boldFont: NSFont, italicFont: NSFont, monoFont: NSFont) {
        let text = attrString.string as NSString
        
        // Highlight ==text==
        applyPattern(#"==([^=\n]+)=="#, to: attrString, text: text) { range, innerRange in
            attrString.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.4), range: innerRange)
            // Remove the == markers
            attrString.replaceCharacters(in: NSRange(location: range.location + range.length - 2, length: 2), with: "")
            attrString.replaceCharacters(in: NSRange(location: range.location, length: 2), with: "")
        }
        
        // Bold **text** or __text__
        for pattern in [#"\*\*([^*\n]+)\*\*"#, #"__([^_\n]+)__"#] {
            applyPatternSimple(pattern, to: attrString, markers: 2) { innerRange in
                attrString.addAttribute(.font, value: boldFont, range: innerRange)
            }
        }
        
        // Italic *text* or _text_
        for pattern in [#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, #"(?<!_)_([^_\n]+)_(?!_)"#] {
            applyPatternSimple(pattern, to: attrString, markers: 1) { innerRange in
                attrString.addAttribute(.font, value: italicFont, range: innerRange)
            }
        }
        
        // Strikethrough ~~text~~
        applyPatternSimple(#"~~([^~\n]+)~~"#, to: attrString, markers: 2) { innerRange in
            attrString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
        }
        
        // Inline code `text`
        applyPatternSimple(#"`([^`\n]+)`"#, to: attrString, markers: 1) { innerRange in
            attrString.addAttribute(.font, value: monoFont, range: innerRange)
            attrString.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: innerRange)
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
    
    private static func applyPattern(_ pattern: String, to attrString: NSMutableAttributedString, text: NSString, apply: (NSRange, NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        var offset = 0
        let matches = regex.matches(in: String(text), options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            let adjustedLocation = match.range.location - offset
            let innerLocation = match.range(at: 1).location - offset
            let innerLength = match.range(at: 1).length
            let adjustedRange = NSRange(location: adjustedLocation, length: match.range.length)
            apply(adjustedRange, NSRange(location: innerLocation, length: innerLength))
            offset += 4 // Removed 4 characters (== on each side)
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
}

// MARK: - Editing Session

@Observable
final class MarkdownEditingSession {
    weak var textView: NSTextView?
    
    func wrap(prefix: String, suffix: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let ns = textView.string as NSString
        let selected = ns.substring(with: range)
        
        let alreadyWrapped = selected.hasPrefix(prefix)
            && selected.hasSuffix(suffix)
            && selected.count >= prefix.count + suffix.count
        
        let replacement: String
        var cursor = 0
        if alreadyWrapped {
            replacement = String(selected.dropFirst(prefix.count).dropLast(suffix.count))
            cursor = range.location + replacement.count
        } else if range.length == 0 {
            replacement = prefix + suffix
            cursor = range.location + prefix.count
        } else {
            replacement = prefix + selected + suffix
            cursor = range.location + replacement.count
        }
        replace(range, with: replacement, cursor: cursor)
    }
    
    func toggleLinePrefix(_ prefix: String) {
        guard let textView else { return }
        let ns = textView.string as NSString
        var range = textView.selectedRange()
        if range.length == 0 {
            let line = ns.lineRange(for: NSRange(location: min(range.location, ns.length), length: 0))
            range = line
        } else {
            range = ns.lineRange(for: range)
        }
        let block = ns.substring(with: range)
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let allPrefixed = lines.filter { !$0.isEmpty }.allSatisfy { $0.hasPrefix(prefix) }
        let updated = lines.map { line -> String in
            if line.isEmpty { return line }
            if allPrefixed {
                return String(line.dropFirst(min(prefix.count, line.count)))
            }
            return prefix + line
        }.joined(separator: "\n")
        replace(range, with: updated, cursor: range.location + updated.count)
    }
    
    func insertSnippet(_ snippet: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        replace(range, with: snippet, cursor: range.location + snippet.count)
    }
    
    private func replace(_ range: NSRange, with string: String, cursor: Int) {
        guard let textView else { return }
        guard textView.shouldChangeText(in: range, replacementString: string) else { return }
        textView.replaceCharacters(in: range, with: string)
        textView.didChangeText()
        let safe = min(max(cursor, 0), textView.string.count)
        textView.setSelectedRange(NSRange(location: safe, length: 0))
    }
}

// MARK: - Modern Toolbar

struct MarkdownToolbar: View {
    var session: MarkdownEditingSession
    
    var body: some View {
        HStack(spacing: 0) {
            // Text formatting group
            HStack(spacing: 1) {
                toolButton("bold", help: "Bold (⌘B)") { session.wrap(prefix: "**", suffix: "**") }
                toolButton("italic", help: "Italic (⌘I)") { session.wrap(prefix: "*", suffix: "*") }
                toolButton("strikethrough", help: "Strikethrough") { session.wrap(prefix: "~~", suffix: "~~") }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            
            Spacer().frame(width: 8)
            
            // Highlight
            toolButton("highlighter", help: "Highlight (⌘⇧H)", tint: .yellow) { session.wrap(prefix: "==", suffix: "==") }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            
            Spacer().frame(width: 8)
            
            // Structure group
            HStack(spacing: 1) {
                toolButton("textformat.size", help: "Heading") { session.toggleLinePrefix("# ") }
                toolButton("list.bullet", help: "Bullet list") { session.toggleLinePrefix("- ") }
                toolButton("list.number", help: "Numbered list") { session.toggleLinePrefix("1. ") }
                toolButton("text.quote", help: "Quote") { session.toggleLinePrefix("> ") }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            
            Spacer().frame(width: 8)
            
            // Insert group
            HStack(spacing: 1) {
                toolButton("chevron.left.forwardslash.chevron.right", help: "Code") { session.wrap(prefix: "`", suffix: "`") }
                toolButton("link", help: "Link") { session.wrap(prefix: "[", suffix: "](url)") }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
    }
    
    private func toolButton(_ systemName: String, help: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? Color.primary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Editor (NSTextView wrapper)

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var session: MarkdownEditingSession
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, session: session)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        
        let textView = JournalMarkdownTextView()
        textView.session = session
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Better line spacing
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            return style
        }()
        
        scroll.documentView = textView
        session.textView = textView
        
        // Apply syntax highlighting initially
        context.coordinator.applySyntaxHighlighting(to: textView)
        
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parentText = $text
        context.coordinator.session = session
        guard let textView = nsView.documentView as? JournalMarkdownTextView else { return }
        textView.session = session
        session.textView = textView
        if textView.string != text && !context.coordinator.isEditing {
            textView.string = text
            context.coordinator.applySyntaxHighlighting(to: textView)
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parentText: Binding<String>
        var session: MarkdownEditingSession
        var isEditing = false
        
        init(text: Binding<String>, session: MarkdownEditingSession) {
            parentText = text
            self.session = session
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parentText.wrappedValue = textView.string
            applySyntaxHighlighting(to: textView)
        }
        
        func applySyntaxHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            let fullRange = NSRange(location: 0, length: text.count)
            
            // Reset to base style
            let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
            textStorage.addAttribute(.font, value: baseFont, range: fullRange)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            
            let patterns: [(String, NSColor, NSFont?)] = [
                // Headings - blue
                (#"^#{1,6}\s+.*$"#, NSColor.systemBlue, NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)),
                // Bold markers
                (#"\*\*[^*\n]+\*\*"#, NSColor.systemOrange, NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)),
                (#"__[^_\n]+__"#, NSColor.systemOrange, NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)),
                // Italic markers
                (#"(?<!\*)\*[^*\n]+\*(?!\*)"#, NSColor.systemPurple, nil),
                (#"(?<!_)_[^_\n]+_(?!_)"#, NSColor.systemPurple, nil),
                // Highlight markers
                (#"==[^=\n]+=="#, NSColor.black, nil),
                // Code
                (#"`[^`\n]+`"#, NSColor.systemTeal, NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)),
                // Links
                (#"\[[^\]\n]+\]\([^)\n]+\)"#, NSColor.linkColor, nil),
                // Lists
                (#"^[-*+]\s+"#, NSColor.systemGreen, nil),
                (#"^\d+\.\s+"#, NSColor.systemGreen, nil),
                // Quotes
                (#"^>\s+.*$"#, NSColor.secondaryLabelColor, nil),
                // Strikethrough
                (#"~~[^~\n]+~~"#, NSColor.systemGray, nil),
            ]
            
            for (pattern, color, font) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { continue }
                let matches = regex.matches(in: text, options: [], range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                    if let font = font {
                        textStorage.addAttribute(.font, value: font, range: match.range)
                    }
                    // Special: highlight background for ==text==
                    if pattern.contains("==") {
                        textStorage.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: match.range)
                    }
                }
            }
        }
    }
}

private final class JournalMarkdownTextView: NSTextView {
    weak var session: MarkdownEditingSession?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        let chars = event.charactersIgnoringModifiers ?? ""
        let shift = event.modifierFlags.contains(.shift)
        switch chars.lowercased() {
        case "b":
            session?.wrap(prefix: "**", suffix: "**")
            return true
        case "i":
            session?.wrap(prefix: "*", suffix: "*")
            return true
        case "h" where shift:
            session?.wrap(prefix: "==", suffix: "==")
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

// MARK: - Preview (Rendered markdown)

struct MarkdownPreview: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scroll.documentView = textView
        updateTextView(textView)
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        updateTextView(textView)
    }
    
    private func updateTextView(_ textView: NSTextView) {
        let displayText = text.isEmpty ? "_How was this day?_" : text
        let attributed = JournalMarkdown.attributedString(displayText)
        textView.textStorage?.setAttributedString(attributed)
    }
}
