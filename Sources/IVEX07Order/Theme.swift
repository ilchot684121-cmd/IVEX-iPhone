import SwiftUI

enum IVEXTheme {
    static let navy = Color(red: 11 / 255, green: 34 / 255, blue: 57 / 255)
    static let navySoft = Color(red: 21 / 255, green: 58 / 255, blue: 82 / 255)
    static let green = Color(red: 24 / 255, green: 169 / 255, blue: 103 / 255)
    static let greenDark = Color(red: 8 / 255, green: 122 / 255, blue: 73 / 255)
    static let blue = Color(red: 47 / 255, green: 126 / 255, blue: 187 / 255)
    static let red = Color(red: 197 / 255, green: 59 / 255, blue: 59 / 255)
    static let amber = Color(red: 230 / 255, green: 161 / 255, blue: 26 / 255)
    static let slate = Color(red: 96 / 255, green: 112 / 255, blue: 106 / 255)
    static let appBackground = Color(red: 244 / 255, green: 248 / 255, blue: 246 / 255)
    static let cardBackground = Color(red: 251 / 255, green: 253 / 255, blue: 252 / 255)
    static let softGreen = Color(red: 231 / 255, green: 246 / 255, blue: 238 / 255)
    static let border = Color(red: 217 / 255, green: 229 / 255, blue: 223 / 255)
    static let violet = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
    static let violetSoft = Color(red: 241 / 255, green: 234 / 255, blue: 254 / 255)
    static let text = Color(red: 21 / 255, green: 35 / 255, blue: 29 / 255)
}

struct IVEXBrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(IVEXTheme.green)
            HStack(spacing: 0) {
                Text("IVEX")
                    .foregroundStyle(.white)
                Text(" TRADE")
                    .foregroundStyle(IVEXTheme.green)
            }
            .font(.system(size: 25, weight: .heavy, design: .rounded))
            .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(IVEXTheme.navy.ignoresSafeArea(edges: .top))
    }
}

struct IVEXCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(IVEXTheme.softGreen)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(IVEXTheme.border, lineWidth: 1)
            }
            .shadow(color: IVEXTheme.navy.opacity(0.08), radius: 2, y: 1)
    }
}

struct IVEXSectionTitle: View {
    let icon: String
    let title: String
    var color: Color = IVEXTheme.green

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(IVEXTheme.text)
        }
    }
}

struct IVEXPrimaryButton: View {
    let title: String
    let icon: String
    var color: Color = IVEXTheme.green
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(disabled ? IVEXTheme.slate.opacity(0.55) : color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: color.opacity(disabled ? 0 : 0.18), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct IVEXReportRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundStyle(IVEXTheme.slate)
                Spacer(minLength: 12)
                Text(value)
                    .fontWeight(.bold)
                    .foregroundStyle(IVEXTheme.greenDark)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            Divider().overlay(IVEXTheme.border)
        }
    }
}

struct IVEXEmptyCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(IVEXTheme.slate)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(IVEXTheme.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
