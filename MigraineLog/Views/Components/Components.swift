import SwiftUI

/// Soft filled surface on the tinted background: no border, no shadow.
struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.bgCard))
    }
}

/// Uppercase label above a group of controls.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Pain level as a number on its ramp color.
struct IntensityBadge: View {
    let intensity: Int
    var size: CGFloat = 40

    var body: some View {
        Text("\(intensity)")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(PainRamp.text(intensity))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(PainRamp.fill(intensity)))
            .accessibilityLabel("Pain \(intensity) of 10, \(IntensityLevel(intensity).title.lowercased())")
    }
}

/// 1–10 as ten bars that grow taller with pain, filled up to the pick on the
/// ramp. Big, one-handed targets; the number row and the band name keep it
/// readable without color.
struct IntensityPicker: View {
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pain").font(.headline).foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("\(value) · \(IntensityLevel(value).title)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...10, id: \.self) { n in
                    let on = n <= value
                    Button {
                        value = n
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(on ? PainRamp.fill(n) : AppColors.bgInput)
                                .frame(height: 26 + CGFloat(n) * 4.5)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(n == value ? AppColors.textPrimary : .clear, lineWidth: 2))
                            Text("\(n)")
                                .font(.subheadline.weight(n == value ? .bold : .regular))
                                .foregroundStyle(n == value ? AppColors.bgCard : AppColors.textSecondary)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(n == value ? AppColors.textPrimary : .clear))
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottom)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pain \(n)")
                    .accessibilityAddTraits(n == value ? .isSelected : [])
                }
            }
            HStack {
                Text("Mild")
                Spacer()
                Text("Worst imaginable")
            }
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// Segmented choice on a fill track, with 44pt segments. Selected segments
/// carry the accessibility "selected" trait, like the system control.
struct SegmentedChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.body.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous)
                            .fill(on ? AppColors.bgCard : .clear)
                            .shadow(color: .black.opacity(on ? 0.06 : 0), radius: 2, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: AppShape.chipRadius + 3, style: .continuous).fill(AppColors.bgInput))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Multi-select chips that wrap onto as many lines as they need.
struct ChipGroup<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Set<Item>
    let title: (Item) -> String

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let on = selection.contains(item)
                Button {
                    if on { selection.remove(item) } else { selection.insert(item) }
                } label: {
                    Text(title(item))
                        .font(.body.weight(on ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(on ? .white : AppColors.textPrimary)
                        .background(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous)
                            .fill(on ? AppColors.accentFill : AppColors.bgInput))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Shown at the top pain levels. Points to care, never advises treatment.
struct EmergencyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("Call 911 if this is the worst headache of your life, came on suddenly like a thunderclap, or comes with weakness, numbness, confusion, trouble speaking, a stiff neck with fever, or after a head injury.")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.dangerFill))
        .accessibilityElement(children: .combine)
    }
}

/// Full-width 58pt primary action, thumb-reachable at the bottom of the screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: AppShape.buttonRadius, style: .continuous)
                        .fill(isEnabled ? AppColors.accentFill : AppColors.textSecondary.opacity(0.45))
                        .opacity(configuration.isPressed ? 0.8 : 1)
                )
        }
    }
}

/// Tinted secondary action, same height as the primary.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: AppShape.buttonRadius, style: .continuous)
                .fill(AppColors.accentTint).opacity(configuration.isPressed ? 0.7 : 1))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
