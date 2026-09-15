import AppKit
import SwiftUI

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
    
    static func attributed(_ source: String) -> AttributedString {
        let (markdown, highlights) = extractHighlights(from: source)
        var attributed: AttributedString
        if let parsed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            attributed = parsed
        } else {
            attributed = AttributedString(markdown)
        }
        applyHighlights(&attributed, highlights)
        return attributed
    }
    
    private static func extractHighlights(from source: String) -> (String, [String]) {
        var highlights: [String] = []
        var result = source
        while let range = result.range(of: #"==([^=\n]+)=="#, options: .regularExpression) {
            let match = String(result[range])
            let inner = String(match.dropFirst(2).dropLast(2))
            let token = "«H\(highlights.count)»"
            highlights.append(inner)
            result.replaceSubrange(range, with: token)
        }
        return (result, highlights)
    }
    
    private static func applyHighlights(_ attributed: inout AttributedString, _ highlights: [String]) {
        for (index, original) in highlights.enumerated() {
            let token = "«H\(index)»"
            guard let range = attributed.range(of: token) else { continue }
            var highlighted = AttributedString(original)
            highlighted.backgroundColor = .yellow.opacity(0.45)
            highlighted.foregroundColor = .primary
            attributed.replaceSubrange(range, with: highlighted)
        }
    }
}

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

struct MarkdownToolbar: View {
    var session: MarkdownEditingSession
    
    var body: some View {
        HStack(spacing: 2) {
            tool("bold", help: "Bold (⌘B)") { session.wrap(prefix: "**", suffix: "**") }
            tool("italic", help: "Italic (⌘I)") { session.wrap(prefix: "*", suffix: "*") }
            tool("highlighter", help: "Highlight (⌘⇧H)") { session.wrap(prefix: "==", suffix: "==") }
            tool("strikethrough", help: "Strikethrough") { session.wrap(prefix: "~~", suffix: "~~") }
            divider
            tool("textformat.size.larger", help: "Heading") { session.toggleLinePrefix("# ") }
            tool("list.bullet", help: "Bullet list") { session.toggleLinePrefix("- ") }
            tool("list.number", help: "Numbered list") { session.toggleLinePrefix("1. ") }
            tool("text.quote", help: "Quote") { session.toggleLinePrefix("> ") }
            divider
            tool("chevron.left.forwardslash.chevron.right", help: "Inline code") { session.wrap(prefix: "`", suffix: "`") }
            tool("link", help: "Link") { session.wrap(prefix: "[", suffix: "](url)") }
            tool("minus", help: "Divider") { session.insertSnippet("\n---\n") }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }
    
    private func tool(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var session: MarkdownEditingSession
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, session: session)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        
        let textView = JournalMarkdownTextView()
        textView.session = session
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .textColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scroll.documentView = textView
        session.textView = textView
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
        }
    }
}

private final class JournalMarkdownTextView: NSTextView {
    weak var session: MarkdownEditingSession?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command), event.charactersIgnoringModifiers != nil else {
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

struct MarkdownPreview: View {
    let text: String
    
    var body: some View {
        ScrollView {
            Text(JournalMarkdown.attributed(text.isEmpty ? "_How was this day?_" : text))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }
}
