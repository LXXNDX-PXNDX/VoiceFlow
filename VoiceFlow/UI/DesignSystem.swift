import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let accent = Color(hex: 0x4F6BFF)
    static let accentSoft = Color(hex: 0xE9EDFF)
    static let cyan = Color(hex: 0x22A8B5)
    static let amber = Color(hex: 0xE99A2C)
    static let danger = Color(hex: 0xE45B62)
    static let green = Color(hex: 0x2DA66F)

    // Compatibility aliases used by history/stats while keeping one restrained accent family.
    static let violet = accent
    static let indigo = Color(hex: 0x667BEF)
    static let pink = Color(hex: 0xB568A6)

    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x5974FF), Color(hex: 0x405BEB)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let waveGradient = LinearGradient(
        colors: [Color(hex: 0x6B83FF), Color(hex: 0x3F5DEB)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardCorner: CGFloat = 16
    static let largeCorner: CGFloat = 24
}

/// A native macOS surface with one quiet border and no decorative clutter.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.035), radius: 14, y: 5)
    }
}

struct StatusBadge: View {
    let text: String
    let icon: String
    var tint: Color = Theme.accent

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 1))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Key/value row used throughout settings.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.vertical, 7)
    }
}

struct ModeOption: View {
    let mode: RecognitionMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.accent : Color.secondary)
                    Text(mode.label)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(mode.hint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selected ? Theme.accent.opacity(0.09) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.24) : Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Primary pill button look.
    func accentPill(enabled: Bool = true) -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent).opacity(enabled ? 1 : 0.4))
    }
}
