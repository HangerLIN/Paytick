import Testing
@testable import Paytick

struct PayrollCalculatorTests {
    @Test func calculatesGuangzhouEmployeeDeductionsForTheFirstMonth() {
        let result = PayrollCalculator.calculate(
            grossMonthlyIncome: 8_000,
            configuration: PayrollDeductionConfiguration(taxMonth: 1)
        )

        #expect(abs(result.pensionInsurance - 640) < 0.001)
        #expect(abs(result.medicalInsurance - 160) < 0.001)
        #expect(abs(result.unemploymentInsurance - 16) < 0.001)
        #expect(abs(result.employeeSocialInsurance - 816) < 0.001)
        #expect(abs(result.individualIncomeTax - 65.52) < 0.001)
        #expect(abs(result.netMonthlyIncome - 7_118.48) < 0.001)
    }

    @Test func clampsEachInsuranceBaseIndependently() {
        let result = PayrollCalculator.calculate(
            grossMonthlyIncome: 100_000,
            configuration: PayrollDeductionConfiguration(taxMonth: 1)
        )

        #expect(abs(result.pensionInsurance - 2_208.24) < 0.001)
        #expect(abs(result.medicalInsurance - 623.4) < 0.001)
        #expect(abs(result.unemploymentInsurance - 85.866) < 0.001)
    }

    @Test func appliesCumulativeWithholdingForLaterMonths() {
        let result = PayrollCalculator.calculate(
            grossMonthlyIncome: 10_000,
            configuration: PayrollDeductionConfiguration(taxMonth: 12)
        )

        #expect(abs(result.employeeSocialInsurance - 1_020) < 0.001)
        #expect(abs(result.individualIncomeTax - 398) < 0.001)
        #expect(abs(result.netMonthlyIncome - 8_582) < 0.001)
    }
}
