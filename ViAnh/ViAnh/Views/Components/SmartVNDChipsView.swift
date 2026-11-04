import SwiftUI

// MARK: - SmartVNDChipsView

/// Thanh ngang các chip gợi ý mệnh giá tiền VND thông minh
struct SmartVNDChipsView: View {

    let rawInput: String
    let onSelect: (Int64) -> Void

    private var suggestions: [Int64] {
        SmartVNDSuggestion.suggestions(for: rawInput)
    }

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { amount in
                        Button {
                            HapticManager.shared.selectionChanged()
                            onSelect(amount)
                        } label: {
                            Text(amount.vndFormatted)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.brandGreen)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.brandGreen.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Chọn mệnh giá \(amount.vndFormatted)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

