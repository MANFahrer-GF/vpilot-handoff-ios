import Testing
import Foundation
@testable import Handoff

struct ThemeColorTests {
    private let theme = ControllerTheme.default

    @Test func highlightedRowsUseTheFacilityColourUnchanged() {
        let tower = Controller.preview(callsign: "EDDF_TWR", frequency: 19400, facility: 4, isHighlighted: true)
        let rendered = RGBColor(theme.rowColor(for: tower, darkMode: false))
        #expect(abs(rendered.red - theme.tower.red) < 0.01)
        #expect(abs(rendered.green - theme.tower.green) < 0.01)
    }

    @Test func nonHighlightedRowsAreDarkerThanHighlightedOnes() {
        let highlighted = Controller.preview(callsign: "EDDF_TWR", frequency: 19400, facility: 4, isHighlighted: true)
        let plain = Controller.preview(callsign: "EDDF_TWR", frequency: 19400, facility: 4, isHighlighted: false)
        let bright = RGBColor(theme.rowColor(for: highlighted, darkMode: false))
        let dim = RGBColor(theme.rowColor(for: plain, darkMode: false))
        #expect(dim.luminance < bright.luminance)
    }

    @Test func brightnessSliderMidpointLeavesTheColourUntouched() {
        let base = RGBColor(hex: 0x4A7BC8)
        let unchanged = base.mixedTowardExtremes(0.5)
        #expect(abs(unchanged.red - base.red) < 0.001)
        #expect(abs(unchanged.blue - base.blue) < 0.001)
    }

    @Test func brightnessSliderExtremesReachBlackAndWhite() {
        let base = RGBColor(hex: 0x4A7BC8)
        #expect(base.mixedTowardExtremes(0).luminance < 0.001)
        #expect(base.mixedTowardExtremes(1).luminance > 0.999)
    }

    @Test func atisYellowGetsDarkTextAndDeepPurpleGetsWhite() {
        // The regression this guards: white-on-yellow was unreadable before the
        // contrast threshold existed.
        let atis = Controller.preview(callsign: "LOWW_D_ATIS", frequency: 21730, facility: 0, isHighlighted: true)
        let center = Controller.preview(callsign: "LOVV_CTR", frequency: 32600, facility: 6, isHighlighted: false)
        #expect(theme.textColor(on: RGBColor(theme.rowColor(for: atis, darkMode: false))) == .black)
        #expect(theme.textColor(on: RGBColor(theme.rowColor(for: center, darkMode: false))) == .white)
    }

    @Test func darkModeOffsetOnlyAppliesInDarkMode() {
        let tower = Controller.preview(callsign: "EDDF_TWR", frequency: 19400, facility: 4, isHighlighted: true)
        let light = RGBColor(theme.rowColor(for: tower, darkMode: false))
        let dark = RGBColor(theme.rowColor(for: tower, darkMode: true))
        #expect(dark.luminance < light.luminance)
    }

    @Test func atisIsDetectedByCallsignNotFacilityCode() {
        // ATIS stations come through with no useful facility enum, so the row colour
        // has to key off the callsign or they fall back to the generic grey.
        let atis = Controller.preview(callsign: "LOWW_A_ATIS", frequency: 22955, facility: 0, isHighlighted: true)
        #expect(atis.isAtis)
        #expect(theme.highlightColor(for: atis) == theme.atis)
    }

    @Test func everyPresetGivesDistinctColoursPerFacility() {
        for preset in ControllerTheme.presets {
            let colours = ThemeFacility.allCases.map { $0.color(in: preset) }
            #expect(Set(colours).count == colours.count, "\(preset.name) reuses a colour between facilities")
        }
    }
}

struct ThemeSerializationTests {
    @Test func roundTripsThroughJSON() throws {
        var theme = ControllerTheme.deuteranopiaSafe
        theme.name = "Mein Thema"
        theme.nonHighlightBrightness = 0.31
        let data = try JSONEncoder().encode(theme)
        let restored = try JSONDecoder().decode(ControllerTheme.self, from: data)
        #expect(restored == theme)
    }

    @Test func facilitySetterWritesTheMatchingSlot() {
        var theme = ControllerTheme.default
        let target = RGBColor(hex: 0x123456)
        ThemeFacility.tower.setColor(target, in: &theme)
        #expect(theme.tower == target)
        #expect(theme.ground == ControllerTheme.default.ground)
    }
}

@MainActor
struct ThemeStoreTests {
    /// Each case gets its own defaults suite so the tests don't fight each other
    /// or leave state behind in the app's real preferences.
    private func makeIsolatedDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func editingAPresetForksItRatherThanRedefiningIt() {
        let store = ThemeStore()
        store.apply(.default)
        store.updateActive { $0.nonHighlightBrightness = 0.42 }
        // "Default" must keep meaning default -- an edit becomes a variant.
        #expect(store.active.name != ControllerTheme.default.name)
        #expect(store.active.nonHighlightBrightness == 0.42)
        store.apply(.default)
        #expect(store.active.nonHighlightBrightness == ControllerTheme.default.nonHighlightBrightness)
    }

    @Test func savingUnderANameMakesItSelectable() {
        let store = ThemeStore()
        store.apply(.protanopiaSafe)
        store.saveActive(as: "Cockpit Nacht")
        #expect(store.saved.contains { $0.name == "Cockpit Nacht" })
        #expect(store.active.name == "Cockpit Nacht")
        store.delete(store.saved.first { $0.name == "Cockpit Nacht" }!)
        #expect(!store.saved.contains { $0.name == "Cockpit Nacht" })
    }

    @Test func blankNamesAreRejected() {
        let store = ThemeStore()
        let before = store.saved.count
        store.saveActive(as: "   ")
        #expect(store.saved.count == before)
    }

    @Test func presetsAlwaysComeFirstInThePicker() {
        let store = ThemeStore()
        #expect(store.allThemes.prefix(3).map(\.name) == ControllerTheme.presets.map(\.name))
    }
}
