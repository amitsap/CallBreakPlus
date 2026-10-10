import SwiftUI
import Testing
@testable import CallBreakPlus

@Suite("Table Theme")
struct TableThemeTests {
    @Test(arguments: TableThemeChoice.allCases)
    func proKeepsEveryTheme(choice: TableThemeChoice) {
        #expect(ProGate.tableTheme(selected: choice, hasPro: true) == choice)
    }

    @Test(arguments: TableThemeChoice.allCases)
    func freeShowsClassic(choice: TableThemeChoice) {
        #expect(ProGate.tableTheme(selected: choice, hasPro: false) == (choice.isPro ? .classic : choice))
    }

    @Test func storedThemeValuesSurvive() {
        #expect(TableThemeChoice(stored: 0) == .classic)
        #expect(TableThemeChoice(stored: 99) == .classic)
        #expect(TableThemeChoice.allCases.filter { !$0.isPro } == [.classic])
    }

    @Test @MainActor func refundFallsBackWithoutForgettingTheChoice() {
        let defaults = scratchDefaults()
        var hasPro = true
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.hasPro = { hasPro }
        viewModel.tableTheme = .midnight
        #expect(viewModel.effectiveTableTheme == .midnight)

        hasPro = false
        #expect(viewModel.effectiveTableTheme == .classic)

        let reloaded = GameViewModel(defaults: defaults)
        reloaded.hasPro = { true }
        #expect(reloaded.effectiveTableTheme == .midnight)
    }

    /// White chrome text sits anywhere on the felt, so every felt stop must give it 4.5:1.
    @Test(arguments: TableThemeChoice.allCases)
    func whiteTextKeepsContrastOnTheFelt(choice: TableThemeChoice) {
        for (index, color) in choice.theme.felt.enumerated() {
            let ratio = 1.05 / (relativeLuminance(color) + 0.05)
            #expect(ratio >= 4.5, "\(choice.name) felt stop \(index) gives white \(ratio):1")
        }
    }

    @Test func proThemesLookDifferent() {
        let felts = TableThemeChoice.allCases.map { $0.theme.felt.map(rgb) }
        for (i, a) in felts.enumerated() {
            for b in felts[(i + 1)...] {
                #expect(a.elementsEqual(b, by: ==) == false)
            }
        }
    }

    private struct RGB: Equatable { let r, g, b: Double }

    private func rgb(_ color: Color) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: r, g: g, b: b)
    }

    private func relativeLuminance(_ color: Color) -> Double {
        let c = rgb(color)
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
}
