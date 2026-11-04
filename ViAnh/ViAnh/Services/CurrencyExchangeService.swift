import Foundation
import SwiftUI

// MARK: - Supported Currency

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case vnd = "VND"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .vnd: return "₫"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var decimalDigits: Int {
        switch self {
        case .vnd: return 0
        case .usd, .eur: return 2
        }
    }

    var title: String {
        switch self {
        case .vnd: return "VND (₫) - Việt Nam Đồng"
        case .usd: return "USD ($) - Đô la Mỹ"
        case .eur: return "EUR (€) - Đồng Euro"
        }
    }
}

// MARK: - CurrencyExchangeService

@MainActor
@Observable
final class CurrencyExchangeService {

    static let shared = CurrencyExchangeService()

    /// Tiền tệ hiển thị toàn ứng dụng
    var displayCurrency: SupportedCurrency = .vnd {
        didSet {
            UserDefaults.standard.set(displayCurrency.rawValue, forKey: "app_display_currency")
        }
    }

    /// Tỷ giá: 1 USD = bao nhiêu VND
    var usdToVndRate: Double = 25400.0 {
        didSet {
            UserDefaults.standard.set(usdToVndRate, forKey: "exchange_rate_usd_vnd")
            lastRateUpdate = Date.now
        }
    }

    /// Tỷ giá: 1 EUR = bao nhiêu VND
    var eurToVndRate: Double = 27500.0 {
        didSet {
            UserDefaults.standard.set(eurToVndRate, forKey: "exchange_rate_eur_vnd")
            lastRateUpdate = Date.now
        }
    }

    var lastRateUpdate: Date = Date.now {
        didSet {
            UserDefaults.standard.set(lastRateUpdate.timeIntervalSince1970, forKey: "exchange_rate_last_update")
        }
    }

    var isFetchingRates: Bool = false
    var lastFetchError: String? = nil

    init() {
        if let savedCurr = UserDefaults.standard.string(forKey: "app_display_currency"),
           let c = SupportedCurrency(rawValue: savedCurr) {
            self.displayCurrency = c
        } else {
            self.displayCurrency = .vnd
        }

        let savedUsd = UserDefaults.standard.double(forKey: "exchange_rate_usd_vnd")
        if savedUsd > 0 {
            self.usdToVndRate = savedUsd
        }

        let savedEur = UserDefaults.standard.double(forKey: "exchange_rate_eur_vnd")
        if savedEur > 0 {
            self.eurToVndRate = savedEur
        }

        let savedUpdate = UserDefaults.standard.double(forKey: "exchange_rate_last_update")
        if savedUpdate > 0 {
            self.lastRateUpdate = Date(timeIntervalSince1970: savedUpdate)
        }

        // Tự động tải tỷ giá mới nhất khi khởi chạy
        Task {
            await self.fetchLiveRates()
        }
    }

    /// Lấy tỷ giá hối đoái thị trường trực tuyến tự động theo thời gian thực
    func fetchLiveRates() async {
        guard !isFetchingRates else { return }
        isFetchingRates = true
        lastFetchError = nil

        defer { isFetchingRates = false }

        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            struct ExchangeApiResponse: Codable {
                let result: String?
                let rates: [String: Double]?
            }

            let decoded = try JSONDecoder().decode(ExchangeApiResponse.self, from: data)
            if let rates = decoded.rates, let vnd = rates["VND"], vnd > 1000 {
                self.usdToVndRate = vnd
                if let eur = rates["EUR"], eur > 0 {
                    self.eurToVndRate = vnd / eur
                }
                self.lastRateUpdate = Date.now
            }
        } catch {
            self.lastFetchError = error.localizedDescription
        }
    }

    // MARK: - Conversion

    /// Quy đổi số tiền từ tiền tệ gốc sang tiền tệ hiển thị đang chọn
    func convert(amount: Int64, from sourceCurrency: String = "VND", to targetCurrency: SupportedCurrency? = nil) -> Double {
        let target = targetCurrency ?? displayCurrency
        let sourceUpper = sourceCurrency.uppercased()

        // 1. Đưa về VND chuẩn cơ sở
        let amountInVnd: Double
        if sourceUpper == "VND" {
            amountInVnd = Double(amount)
        } else if sourceUpper == "USD" {
            amountInVnd = Double(amount) * usdToVndRate
        } else if sourceUpper == "EUR" {
            amountInVnd = Double(amount) * eurToVndRate
        } else {
            amountInVnd = Double(amount)
        }

        // 2. Từ VND sang Target Currency
        switch target {
        case .vnd:
            return amountInVnd
        case .usd:
            guard usdToVndRate > 0 else { return amountInVnd }
            return amountInVnd / usdToVndRate
        case .eur:
            guard eurToVndRate > 0 else { return amountInVnd }
            return amountInVnd / eurToVndRate
        }
    }

    // MARK: - Formatting

    /// Định dạng số tiền kèm ký hiệu tiền tệ chuẩn xác
    func format(amountVND: Int64, targetCurrency: SupportedCurrency? = nil, showSign: Bool = false, isExpense: Bool = false) -> String {
        let target = targetCurrency ?? displayCurrency
        let converted = convert(amount: amountVND, from: "VND", to: target)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = target.decimalDigits
        formatter.maximumFractionDigits = target.decimalDigits
        formatter.groupingSeparator = target == .vnd ? "." : ","
        formatter.decimalSeparator = target == .vnd ? "," : "."

        let numStr = formatter.string(from: NSNumber(value: abs(converted))) ?? "\(converted)"

        var result = ""
        switch target {
        case .vnd:
            result = "\(numStr) ₫"
        case .usd:
            result = "$\(numStr)"
        case .eur:
            result = "€\(numStr)"
        }

        if showSign {
            if isExpense {
                return "-\(result)"
            } else {
                return "+\(result)"
            }
        }

        return result
    }

    /// Helper format nhanh từ số tiền VND
    func formatFromVND(_ amountVND: Int64) -> String {
        format(amountVND: amountVND)
    }

    /// Định dạng ngắn gọn cho biểu đồ (ví dụ: 460k hoặc $18.5)
    func formatShort(amountVND: Int64) -> String {
        let target = displayCurrency
        let val = convert(amount: amountVND, from: "VND", to: target)

        switch target {
        case .vnd:
            if val >= 1_000_000 {
                return String(format: "%.1fM ₫", val / 1_000_000)
            } else if val >= 1_000 {
                return String(format: "%.0fk", val / 1_000)
            } else {
                return "\(Int(val)) ₫"
            }
        case .usd, .eur:
            let sym = target.symbol
            if val >= 1_000 {
                return String(format: "%@%.1fk", sym, val / 1_000)
            } else {
                return String(format: "%@%.1f", sym, val)
            }
        }
    }
}
