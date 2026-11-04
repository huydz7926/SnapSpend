import SwiftUI

// MARK: - PolaroidCardView

/// Thẻ Polaroid card — USP chính của Ví Ảnh
/// Khung trắng, ảnh trên, tem giá và thông tin ở chân thẻ
struct PolaroidCardView: View {

    let expense: ExpenseItem

    var body: some View {
        VStack(spacing: 0) {
            // Phần ảnh vuông
            AsyncThumbnailView(
                fileName: expense.thumbnailFileName,
                category: expense.category
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            // Chân thẻ Polaroid
            VStack(alignment: .leading, spacing: 4) {
                // Tem giá VND nổi bật
                Text(expense.amountVND.vndFormatted)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    Text(expense.displayTitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Text(DateHelpers.relativeDayString(from: expense.spentAt))
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.displayTitle), số tiền \(expense.amountVND.vndFormatted), ngày \(DateHelpers.relativeDayString(from: expense.spentAt))")
    }
}

