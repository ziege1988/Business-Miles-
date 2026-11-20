import SwiftUI

/// Liest Zahlen so, wie Menschen sie tippen: "12,5", "12.5", "1.264,8", "0.42", "45 km".
/// (Identisch zu parseDecimal in web/js/format.js.)
enum DecimalParser {
    static func parse(_ input: String, allowsThousands: Bool) -> Double? {
        var s = String(input.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" })
        guard !s.isEmpty, s != "-" else { return nil }
        let lastDot = s.lastIndex(of: "."), lastComma = s.lastIndex(of: ",")
        if let dot = lastDot, let comma = lastComma {
            // Beide vorhanden: das letzte Zeichen ist der Dezimaltrenner
            let decimalIsDot = dot > comma
            s = s.replacingOccurrences(of: decimalIsDot ? "," : ".", with: "")
            if !decimalIsDot { s = s.replacingOccurrences(of: ",", with: ".") }
        } else if lastComma != nil {
            s = s.replacingOccurrences(of: ".", with: "")
            if let last = s.lastIndex(of: ",") {
                let head = s[..<last].replacingOccurrences(of: ",", with: "")
                s = head + "." + s[s.index(after: last)...]
            }
        } else if lastDot != nil {
            let groups = s.split(separator: ".", omittingEmptySubsequences: false)
            let looksLikeThousands = groups.count > 1 && groups.first.map { (1...3).contains($0.count) } == true
                && groups.dropFirst().allSatisfy { $0.count == 3 }
            if allowsThousands && looksLikeThousands {
                s = s.replacingOccurrences(of: ".", with: "")
            } else if let last = s.lastIndex(of: ".") {
                let head = s[..<last].replacingOccurrences(of: ".", with: "")
                s = head + "." + s[s.index(after: last)...]
            }
        }
        return Double(s)
    }
}

/// Zahlenfeld, das jede Eingabe sofort übernimmt (auch wenn man direkt „Sichern“ klickt)
/// und erst beim Verlassen schön formatiert.
struct DecimalField: View {
    let title: String
    @Binding var value: Double
    var fractionDigits: Int = 1
    var allowsThousands: Bool = true
    /// Wird aufgerufen, wenn der Nutzer selbst etwas eintippt
    var onUserEdit: (() -> Void)? = nil

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text, prompt: Text(format(0)))
            .focused($focused)
            .multilineTextAlignment(.trailing)
            .onAppear { text = format(value) }
            .onChange(of: text) { _, newText in
                guard focused else { return }
                let parsed = DecimalParser.parse(newText, allowsThousands: allowsThousands)
                    ?? (newText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : nil)
                if let parsed, parsed != value {
                    value = max(0, parsed)
                    onUserEdit?()
                }
            }
            .onChange(of: value) { _, newValue in
                if !focused { text = format(newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = format(value) }
            }
            .onSubmit { text = format(value) }
    }

    private func format(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Fmt.locale
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = max(fractionDigits, 3)
        return f.string(from: NSNumber(value: v)) ?? ""
    }
}
