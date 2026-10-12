import SwiftUI

/// One task in the day list.
///
/// Checklist tasks keep the status circle. Percent, count, and hours tasks
/// share a single progress pill. Tapping the pill opens an editor in place,
/// with a slider, minus and plus, and a field for typing the value.
struct GoalRow: View {
    let goal: Goal
    let entry: GoalEntry
    var showsEssentialBadge: Bool = false
    var isOneOff: Bool = false
    var onEdit: (() -> Void)? = nil
    var onSetPercent: (Int) -> Void = { _ in }
    var onSetAmount: (Int) -> Void = { _ in }
    var onAdjustAmount: (Int) -> Void = { _ in }
    let onStatusChange: () -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    
    private var isQuantitative: Bool { goal.kind != .checklist }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GoalIconView(icon: goal.icon, size: 14)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(goal.title)
                            .font(.body)
                            .lineLimit(1)
                        if isOneOff {
                            Image(systemName: "1.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .help("One-off task for this day only")
                        }
                        if showsEssentialBadge {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    if let caption = goal.rowCaption {
                        Text(caption)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isQuantitative {
                        toggleExpanded()
                    } else if isOneOff {
                        onEdit?()
                    }
                }
                
                Spacer(minLength: 8)
                
                if isQuantitative {
                    ProgressPill(goal: goal, entry: entry, isExpanded: isExpanded) {
                        incrementFromPill()
                    }
                } else {
                    StatusButton(status: entry.status, size: 26, action: onStatusChange)
                }
            }
            .frame(minHeight: 44)
            
            if isExpanded && isQuantitative {
                GoalProgressEditor(
                    goal: goal,
                    entry: entry,
                    onSetPercent: onSetPercent,
                    onSetAmount: onSetAmount,
                    onAdjustAmount: onAdjustAmount
                )
                .padding(.leading, 14 + 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isExpanded ? Color.gray.opacity(0.14) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onExitCommand {
            guard isExpanded else { return }
            toggleExpanded()
        }
    }
    
    private func incrementFromPill() {
        switch goal.kind {
        case .percent:
            if entry.resolvedPercent >= 100 {
                onSetPercent(0)
            } else {
                onSetPercent(min(100, entry.resolvedPercent + goal.safePercentStep))
            }
        case .count:
            let current = entry.resolvedAmount(for: goal)
            if current >= goal.safeTarget {
                onSetAmount(0)
            } else {
                onAdjustAmount(goal.safeCountStep)
            }
        case .hours:
            onAdjustAmount(goal.safeHourStep)
        case .checklist:
            break
        }
    }
    
    private func toggleExpanded() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - Progress pill

/// Compact capsule showing today's value with a fill behind it.
private struct ProgressPill: View {
    let goal: Goal
    let entry: GoalEntry
    var isExpanded: Bool
    var action: () -> Void
    
    private var current: Int { entry.resolvedAmount(for: goal) }
    private var progress: Double { entry.progressValue(for: goal) }
    private var overLimit: Bool { goal.isOverHourLimit(current) }
    
    private var fillRatio: Double {
        switch goal.kind {
        case .hours where goal.hourBound == .atMost || goal.hourBound == .between:
            let ceiling = Double(max(1, goal.safeTargetMinutes))
            return min(1, Double(current) / ceiling)
        default:
            return min(1, max(0, progress))
        }
    }
    
    private var isComplete: Bool {
        switch goal.kind {
        case .percent: return entry.resolvedPercent >= 100
        case .count: return current >= goal.safeTarget
        case .hours:
            switch goal.hourBound {
            case .atLeast:
                return current >= goal.safeTargetMinutes
            case .atMost:
                return !overLimit
            case .between:
                return current >= goal.safeFloorMinutes && !overLimit
            }
        case .checklist: return false
        }
    }
    
    private var tint: Color {
        if overLimit { return .red }
        if isComplete { return .green }
        if goal.kind == .hours, goal.hourBound == .atMost {
            return fillRatio >= 0.85 ? .orange : .green.opacity(0.85)
        }
        return GoalStatus.tint(for: fillRatio)
    }
    
    private var label: String {
        switch goal.kind {
        case .percent: return "\(entry.resolvedPercent)%"
        case .count: return "\(current) / \(goal.safeTarget)"
        case .hours: return Goal.formatMinutes(current)
        case .checklist: return ""
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                } else if overLimit {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .contentTransition(.numericText())
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .frame(minWidth: 60, minHeight: 26)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(tint.opacity(fillRatio >= 1 || overLimit ? 1 : 0.9))
                            .frame(width: max(fillRatio > 0 ? 12 : 0, geo.size.width * fillRatio))
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isExpanded ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(StatusButtonStyle())
        .animation(.easeOut(duration: 0.18), value: fillRatio)
        .accessibilityLabel(entry.progressDescription(for: goal))
        .accessibilityHint(goal.kind == .hours
            ? "Adds time, including past the limit."
            : "Adds one step. When full, tap once to reset.")
        .help(entry.weekHelp(for: goal))
    }
    
    private var textColor: Color {
        if fillRatio >= 0.5 || overLimit { return .white }
        return .primary
    }
}

// MARK: - In-place editor

/// Slider with minus and plus, and a typed value for percent and count.
private struct GoalProgressEditor: View {
    let goal: Goal
    let entry: GoalEntry
    var onSetPercent: (Int) -> Void
    var onSetAmount: (Int) -> Void
    var onAdjustAmount: (Int) -> Void
    
    @State private var dragValue: Double?
    
    private var current: Int {
        goal.kind == .percent ? entry.resolvedPercent : entry.resolvedAmount(for: goal)
    }
    
    private var shown: Int {
        Int((dragValue ?? Double(current)).rounded())
    }
    
    private var upper: Double {
        switch goal.kind {
        case .percent: return 100
        case .count: return Double(goal.safeTarget)
        case .hours:
            let limit = Double(goal.safeTargetMinutes)
            return max(limit * 2, Double(current + goal.safeHourStep))
        case .checklist: return 1
        }
    }
    
    private var hourMarks: [Double] {
        guard goal.kind == .hours else { return [] }
        switch goal.hourBound {
        case .atLeast, .atMost:
            return [Double(goal.safeTargetMinutes)]
        case .between:
            return [Double(goal.safeFloorMinutes), Double(goal.safeTargetMinutes)]
        }
    }
    
    private var smallDelta: Int {
        switch goal.kind {
        case .percent: return goal.safePercentStep
        case .hours: return goal.safeHourStep
        default: return goal.safeCountStep
        }
    }
    
    private var canIncrease: Bool {
        switch goal.kind {
        case .percent: return current < 100
        case .count: return current < goal.safeTarget
        case .hours: return true
        case .checklist: return false
        }
    }
    
    private var tint: Color {
        if goal.isOverHourLimit(current) { return .red }
        return GoalStatus.tint(for: entry.progressValue(for: goal))
    }
    
    var body: some View {
        HStack(spacing: 10) {
            StepCircleButton(systemName: "minus", enabled: current > 0, label: decreaseLabel) {
                adjust(-smallDelta)
            }
            
            TrackSlider(
                value: dragValue ?? Double(current),
                range: 0...max(upper, 1),
                tint: tint,
                stops: goal.kind == .count ? goal.safeTarget : nil,
                marks: hourMarks
            ) { next, ended in
                let snapped = goal.kind == .count ? next.rounded() : next
                dragValue = snapped
                if ended {
                    commit(Int(snapped.rounded()))
                    dragValue = nil
                }
            }
            .accessibilityLabel(goal.title)
            .accessibilityValue(valueText)
            
            StepCircleButton(systemName: "plus", enabled: canIncrease, label: increaseLabel) {
                adjust(smallDelta)
            }
            
            valueView
        }
    }
    
    @ViewBuilder
    private var valueView: some View {
        switch goal.kind {
        case .hours:
            Text(Goal.formatMinutes(shown))
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
                .contentTransition(.numericText())
        case .percent:
            InlineNumberField(value: shown, maximum: 100, suffix: "%") { commit($0) }
        case .count:
            InlineNumberField(value: shown, maximum: goal.safeTarget, suffix: nil) { commit($0) }
        case .checklist:
            EmptyView()
        }
    }
    
    private var valueText: String {
        switch goal.kind {
        case .percent: return "\(shown) percent"
        case .hours: return Goal.formatMinutes(shown)
        default: return "\(shown)"
        }
    }
    
    private var decreaseLabel: String {
        switch goal.kind {
        case .percent: return "Decrease by \(goal.safePercentStep) percent"
        case .hours: return "Remove \(Goal.formatMinutes(goal.safeHourStep))"
        default: return "Decrease by \(goal.safeCountStep)"
        }
    }
    
    private var increaseLabel: String {
        switch goal.kind {
        case .percent: return "Increase by \(goal.safePercentStep) percent"
        case .hours: return "Add \(Goal.formatMinutes(goal.safeHourStep))"
        default: return "Increase by \(goal.safeCountStep)"
        }
    }
    
    private func adjust(_ delta: Int) {
        switch goal.kind {
        case .percent: onSetPercent(min(100, max(0, current + delta)))
        default: onAdjustAmount(delta)
        }
    }
    
    private func commit(_ value: Int) {
        switch goal.kind {
        case .percent: onSetPercent(min(100, max(0, value)))
        default: onSetAmount(max(0, value))
        }
    }
}

/// A short digits-only field. Stays within 0...maximum and commits on Return or blur.
private struct InlineNumberField: View {
    let value: Int
    let maximum: Int
    let suffix: String?
    var onCommit: (Int) -> Void
    
    @State private var text = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            TextField("0", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(width: CGFloat(max(String(maximum).count, 2)) * 8 + 6)
                .focused($focused)
            if let suffix {
                Text(suffix)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(focused ? 0.12 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(focused ? Color.accentColor.opacity(0.8) : Color.clear, lineWidth: 1)
        )
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, newValue in
            guard !focused else { return }
            text = "\(newValue)"
        }
        .onChange(of: text) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(4))
            if digits != newValue { text = digits }
        }
        .onSubmit { commit() }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .accessibilityLabel("Value")
        .accessibilityValue("\(value) of \(maximum)")
    }
    
    private func commit() {
        let number = Int(text.filter(\.isNumber)) ?? 0
        let clamped = min(maximum, max(0, number))
        text = "\(clamped)"
        if clamped != value { onCommit(clamped) }
    }
}

/// A fill and knob. Count sliders also mark each step.
private struct TrackSlider: View {
    let value: Double
    var range: ClosedRange<Double>
    var tint: Color
    /// Number of count steps. Draws a mark at each step, including zero.
    var stops: Int? = nil
    /// Hour limits, in minutes, drawn as ticks you can pass.
    var marks: [Double] = []
    var onChange: (Double, Bool) -> Void
    
    private var showsLabels: Bool { (stops ?? 0) > 0 && (stops ?? 0) <= 10 }
    private var visibleStops: [Int] {
        guard let stops, stops > 0 else { return [] }
        if stops <= 20 { return Array(0...stops) }
        let stride = Int((Double(stops) / 10).rounded(.up))
        return Array(Swift.stride(from: 0, through: stops, by: stride)) + (stops % stride == 0 ? [] : [stops])
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = max(width - knob, 1)
            let ratio = positionRatio
            VStack(spacing: 1) {
                Color.clear
                    .frame(width: width, height: knob)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.14))
                            .frame(width: width, height: 4)
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: max(4, knob / 2 + span * ratio), height: 4)
                    }
                    .overlay(alignment: .leading) {
                        ZStack(alignment: .leading) {
                            ForEach(visibleStops, id: \.self) { stop in
                                Circle()
                                    .fill(Color.primary.opacity(0.55))
                                    .frame(width: 5, height: 5)
                                    .offset(x: centerX(span: span, ratio: stopRatio(stop)) - 2.5)
                            }
                        }
                        .frame(width: width, height: knob, alignment: .leading)
                    }
                    .overlay(alignment: .leading) {
                        ZStack(alignment: .leading) {
                            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.primary.opacity(0.75))
                                    .frame(width: 2, height: 12)
                                    .offset(x: centerX(span: span, ratio: markRatio(mark)) - 1)
                            }
                        }
                        .frame(width: width, height: knob, alignment: .leading)
                    }
                    .overlay(alignment: .leading) {
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
                            .frame(width: knob, height: knob)
                            .offset(x: span * ratio)
                    }
                
                if showsLabels, let stops {
                    Color.clear
                        .frame(width: width, height: 12)
                        .overlay(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                ForEach(0...stops, id: \.self) { stop in
                                    Text("\(stop)")
                                        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                                        .foregroundStyle(Color.secondary)
                                        .frame(width: labelWidth, alignment: .center)
                                        .offset(x: centerX(span: span, ratio: stopRatio(stop)) - labelWidth / 2)
                                }
                            }
                            .frame(width: width, height: 12, alignment: .leading)
                        }
                }
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onChange(value(at: drag.location.x, span: span), false)
                    }
                    .onEnded { drag in
                        onChange(value(at: drag.location.x, span: span), true)
                    }
            )
        }
        .frame(height: showsLabels ? 32 : 22)
        .accessibilityElement()
        .accessibilityAdjustableAction { direction in
            let delta = stops != nil ? 1 : (range.upperBound - range.lowerBound) / 20
            let next = direction == .increment ? value + delta : value - delta
            onChange(min(range.upperBound, max(range.lowerBound, next)), true)
        }
    }
    
    private var labelWidth: CGFloat { 16 }
    
    /// Knob center for a 0...1 position along the travel.
    private func centerX(span: CGFloat, ratio: Double) -> CGFloat {
        knob / 2 + span * ratio
    }
    
    private func markRatio(_ mark: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (mark - range.lowerBound) / span))
    }
    
    private func stopRatio(_ stop: Int) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (Double(stop) - range.lowerBound) / span))
    }
    
    private var knob: CGFloat { 16 }
    
    private var positionRatio: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }
    
    private func value(at x: CGFloat, span: CGFloat) -> Double {
        let ratio = min(1, max(0, (x - knob / 2) / span))
        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio
    }
}

private struct StepCircleButton: View {
    let systemName: String
    let enabled: Bool
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.35)))
                .background {
                    Circle().fill(Color.primary.opacity(enabled ? 0.1 : 0.05))
                }
        }
        .buttonStyle(StatusButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Compact goal row for week view
struct CompactGoalRow: View {
    let goal: Goal
    let entries: [GoalEntry]  // 7 days
    let onStatusChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Goal icon & title
            HStack(spacing: 6) {
                GoalIconView(icon: goal.icon, size: 10)
                
                Text(goal.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
            
            // Week status dots
            HStack(spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    Button {
                        onStatusChange(index)
                    } label: {
                        StatusDot(status: entry.status, size: 16)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("Goal Row") {
    let readId = UUID()
    let waterId = UUID()
    let focusId = UUID()
    VStack(spacing: 2) {
        GoalRow(
            goal: Goal(title: "Exercise", icon: "figure.run"),
            entry: GoalEntry(goalId: UUID(), date: Date(), status: .done),
            onStatusChange: {}
        )
        GoalRow(
            goal: Goal(id: readId, title: "Read", icon: "book.fill", kind: .percent),
            entry: GoalEntry(goalId: readId, date: Date(), status: .partial, percent: 40),
            onStatusChange: {}
        )
        GoalRow(
            goal: Goal(id: waterId, title: "Drink Water", icon: "drop.fill", kind: .count, targetCount: 8, unit: "glasses"),
            entry: GoalEntry(goalId: waterId, date: Date(), status: .partial, amount: 3),
            onStatusChange: {}
        )
        GoalRow(
            goal: Goal(id: focusId, title: "Deep Work", icon: "brain.head.profile", kind: .hours, step: 15, hourBound: .atLeast, targetMinutes: 120),
            entry: GoalEntry(goalId: focusId, date: Date(), status: .partial, amount: 75),
            onStatusChange: {}
        )
    }
    .frame(width: 400)
    .padding()
}
