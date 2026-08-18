import SwiftUI

enum IVEXTheme {
    static let navy = Color(red: 7/255, green: 28/255, blue: 44/255)
    static let navySoft = Color(red: 16/255, green: 52/255, blue: 74/255)
    static let green = Color(red: 28/255, green: 169/255, blue: 91/255)
    static let softGreen = Color(red: 236/255, green: 248/255, blue: 241/255)
    static let orange = Color(red: 242/255, green: 153/255, blue: 27/255)
}

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.headline).bold()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.08)))
    }
}
