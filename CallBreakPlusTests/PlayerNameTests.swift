import Testing
@testable import CallBreakPlus

@Suite("Player Name")
struct PlayerNameTests {
    @Test @MainActor func nameIsCappedAtTwelveCharacters() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.playerName = "Bishnu Prasad Koirala"
        #expect(viewModel.playerName == "Bishnu Prasa")
        #expect(viewModel.seatName(.bottom) == "Bishnu Prasa")
    }

    @Test @MainActor func emptyOrBlankNameShowsYou() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.playerName = ""
        #expect(viewModel.seatName(.bottom) == "You")
        viewModel.playerName = "   "
        #expect(viewModel.seatName(.bottom) == "You")
    }

    @Test @MainActor func seatNameTrimsSpaces() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.playerName = "  Asha "
        #expect(viewModel.seatName(.bottom) == "Asha")
    }

    @Test @MainActor func storedLongNameIsCappedOnLoad() {
        let defaults = scratchDefaults()
        defaults.set("A name stored before the cap", forKey: "settings.playerName")
        let viewModel = GameViewModel(defaults: defaults)
        #expect(viewModel.playerName == "A name store")
    }
}
