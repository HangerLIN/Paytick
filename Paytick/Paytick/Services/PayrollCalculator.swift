import Foundation
import Combine

/// Personal payroll settings. The default policy is for a Guangzhou enterprise employee in 2026.
/// Rates and contribution bases are persisted so that a user can match their payslip when policy or
/// employer-declared bases differ.
final class PayrollDeductionSettings: ObservableObject {
    static let shared = PayrollDeductionSettings()

    @Published var isEnabled: Bool { didSet { save() } }
    /// A value of 0 follows the configured gross monthly salary.
    @Published var contributionBase: Double { didSet { save() } }
    @Published var monthlySpecialAdditionalDeduction: Double { didSet { save() } }
    /// The current salary month in the calendar year. It is used by the cumulative withholding estimate.
    @Published var taxMonth: Int { didSet { save() } }

    private enum Key {
        static let enabled = "payrollDeductionEnabled"
        static let contributionBase = "payrollContributionBase"
        static let additionalDeduction = "payrollMonthlySpecialAdditionalDeduction"
        static let taxMonth = "payrollTaxMonth"
    }

    private init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        contributionBase = defaults.double(forKey: Key.contributionBase)
        monthlySpecialAdditionalDeduction = defaults.double(forKey: Key.additionalDeduction)

        let savedTaxMonth = defaults.integer(forKey: Key.taxMonth)
        let currentMonth = calendar.component(.month, from: Date())
        taxMonth = (1...12).contains(savedTaxMonth) ? savedTaxMonth : currentMonth
    }

    var configuration: PayrollDeductionConfiguration {
        PayrollDeductionConfiguration(
            isEnabled: isEnabled,
            contributionBase: contributionBase,
            monthlySpecialAdditionalDeduction: monthlySpecialAdditionalDeduction,
            taxMonth: taxMonth
        )
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Key.enabled)
        defaults.set(max(0, contributionBase), forKey: Key.contributionBase)
        defaults.set(max(0, monthlySpecialAdditionalDeduction), forKey: Key.additionalDeduction)
        defaults.set(min(max(taxMonth, 1), 12), forKey: Key.taxMonth)
    }
}

struct PayrollDeductionConfiguration: Equatable {
    var isEnabled: Bool = true
    /// 0 means to use the employee's gross monthly salary as the declared contribution base.
    var contributionBase: Double = 0
    var monthlySpecialAdditionalDeduction: Double = 0
    var taxMonth: Int

    init(
        isEnabled: Bool = true,
        contributionBase: Double = 0,
        monthlySpecialAdditionalDeduction: Double = 0,
        taxMonth: Int = Calendar.current.component(.month, from: Date())
    ) {
        self.isEnabled = isEnabled
        self.contributionBase = contributionBase
        self.monthlySpecialAdditionalDeduction = monthlySpecialAdditionalDeduction
        self.taxMonth = min(max(taxMonth, 1), 12)
    }
}

struct PayrollBreakdown: Equatable {
    let grossMonthlyIncome: Double
    let pensionInsurance: Double
    let medicalInsurance: Double
    let unemploymentInsurance: Double
    let employeeSocialInsurance: Double
    let individualIncomeTax: Double
    let netMonthlyIncome: Double

    static let zero = PayrollBreakdown(
        grossMonthlyIncome: 0,
        pensionInsurance: 0,
        medicalInsurance: 0,
        unemploymentInsurance: 0,
        employeeSocialInsurance: 0,
        individualIncomeTax: 0,
        netMonthlyIncome: 0
    )
}

enum PayrollCalculator {
    // Guangzhou enterprise-employee personal contribution rates for 2026.
    private static let pensionRate = 0.08
    private static let medicalRate = 0.02
    private static let unemploymentRate = 0.002

    // Contribution-base limits can be superseded by a user's declared base.
    private static let pensionBaseRange = 5_521.0...27_603.0
    private static let medicalBaseRange = 6_234.0...31_170.0
    private static let unemploymentBaseRange = 2_680.0...42_933.0
    private static let standardMonthlyDeduction = 5_000.0

    static func calculate(
        grossMonthlyIncome: Double,
        configuration: PayrollDeductionConfiguration
    ) -> PayrollBreakdown {
        let gross = max(0, grossMonthlyIncome)
        guard configuration.isEnabled, gross > 0 else {
            return PayrollBreakdown(
                grossMonthlyIncome: gross,
                pensionInsurance: 0,
                medicalInsurance: 0,
                unemploymentInsurance: 0,
                employeeSocialInsurance: 0,
                individualIncomeTax: 0,
                netMonthlyIncome: gross
            )
        }

        let declaredBase = configuration.contributionBase > 0 ? configuration.contributionBase : gross
        let pension = clamp(declaredBase, to: pensionBaseRange) * pensionRate
        let medical = clamp(declaredBase, to: medicalBaseRange) * medicalRate
        let unemployment = clamp(declaredBase, to: unemploymentBaseRange) * unemploymentRate
        let socialInsurance = pension + medical + unemployment

        let month = Double(configuration.taxMonth)
        let monthlyAdditionalDeduction = max(0, configuration.monthlySpecialAdditionalDeduction)
        let monthlyTaxableIncome = max(0, gross - socialInsurance - standardMonthlyDeduction - monthlyAdditionalDeduction)
        let cumulativeTax = tax(for: monthlyTaxableIncome * month)
        let previousCumulativeTax = tax(for: monthlyTaxableIncome * max(0, month - 1))
        let currentMonthTax = max(0, cumulativeTax - previousCumulativeTax)

        return PayrollBreakdown(
            grossMonthlyIncome: gross,
            pensionInsurance: pension,
            medicalInsurance: medical,
            unemploymentInsurance: unemployment,
            employeeSocialInsurance: socialInsurance,
            individualIncomeTax: currentMonthTax,
            netMonthlyIncome: max(0, gross - socialInsurance - currentMonthTax)
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Individual income tax table for resident salary income under the cumulative withholding method.
    private static func tax(for taxableIncome: Double) -> Double {
        switch taxableIncome {
        case ...36_000:
            return taxableIncome * 0.03
        case ...144_000:
            return taxableIncome * 0.10 - 2_520
        case ...300_000:
            return taxableIncome * 0.20 - 16_920
        case ...420_000:
            return taxableIncome * 0.25 - 31_920
        case ...660_000:
            return taxableIncome * 0.30 - 52_920
        case ...960_000:
            return taxableIncome * 0.35 - 85_920
        default:
            return taxableIncome * 0.45 - 181_920
        }
    }
}
