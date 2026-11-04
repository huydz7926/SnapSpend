import SwiftUI

// MARK: - AmountInputStep

struct AmountInputStep: View {

    @Binding var amount: Int64
    @Binding var rawInput: String
    let image: UIImage?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Ảnh nhỏ nếu có
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 8)
            } else {
                Spacer().frame(height: 20)
            }

            Text("Số tiền chi tiêu")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

            // Hiển thị số tiền lớn
            Text(amount.vndFormatted)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal)

            Divider()
                .padding(.horizontal, 40)

            // Smart VND Chips gợi ý
            SmartVNDChipsView(rawInput: rawInput) { selectedAmount in
                amount = selectedAmount
                rawInput = "\(selectedAmount)"
            }

            Spacer()

            // Bàn phím số tự dựng (Custom Keypad)
            numericKeypad

            // Nút tiếp tục
            Button(action: onContinue) {
                Text("Chọn danh mục →")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(amount > 0 ? Color.brandGreen : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(amount <= 0)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Keypad

    private var numericKeypad: some View {
        VStack(spacing: 12) {
            ForEach([
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
                ["000", "0", "⌫"]
            ], id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key: key)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func keypadButton(key: String) -> some View {
        Button {
            handleKey(key)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 52)

                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.title3.weight(.medium))
                } else {
                    Text(key)
                        .font(.title2.weight(.medium))
                }
            }
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func handleKey(_ key: String) {
        HapticManager.shared.selectionChanged()

        if key == "⌫" {
            if !rawInput.isEmpty {
                rawInput.removeLast()
                amount = Int64(rawInput) ?? 0
            }
        } else if key == "000" {
            if !rawInput.isEmpty && rawInput != "0" && rawInput.count + 3 <= 11 {
                rawInput += "000"
                amount = Int64(rawInput) ?? 0
            }
        } else {
            if rawInput == "0" {
                rawInput = key
            } else if rawInput.count < 11 { // Giới hạn dưới 100 tỷ
                rawInput += key
            }
            amount = Int64(rawInput) ?? 0
        }
    }
}

