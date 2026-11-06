// ScreenshotTests.swift
// luksMusicUITests
//
// Walks through the main screens on a fresh install and attaches App Store screenshots
// (exported by .github/workflows/screenshots.yml). Steps are best-effort so one missing
// element doesn't cost the remaining screenshots.

import XCTest

final class ScreenshotTests: XCTestCase {

    private let app = XCUIApplication()

    func testAppStoreScreenshots() {
        app.launch()

        let guestButton = app.buttons["Continuar como Convidado (Offline)"]
        if guestButton.waitForExistence(timeout: 15) {
            capture("05-login")
            guestButton.tap()
        }

        let furElise = element(containing: "Für Elise (Bagatelle No. 25)")
        if furElise.waitForExistence(timeout: 15) {
            // Let the online scores row load above the user's scores
            pause(4)
            capture("01-library")
            furElise.tap()
        }

        let playButton = app.buttons["playPauseButton"]
        if playButton.waitForExistence(timeout: 15) {
            // Let the engraved score render in the web view
            pause(5)
            playButton.tap()
            waitForLabel(playButton, "Pausar")
            // A few measures in, with both hands playing
            pause(8)
            capture("13-score-playing")
            playButton.tap()
            waitForLabel(playButton, "Tocar")
            // Back to the first note so the title and the opening notes are on screen
            tapIfExists(app.buttons["Voltar ao início"])
            pause(2)
            capture("02-score")

            // Step note by note: the cursor, the lit keys and the note names follow
            for _ in 0..<3 {
                tapIfExists(app.buttons["nextNoteButton"])
                pause(0.5)
            }
            pause(1)
            capture("11-score-steps")

            if tapIfExists(app.buttons["scoreMenuButton"]) {
                pause(1)
                capture("06-score-menu")
                if tapIfExists(app.buttons["Configurações"]) {
                    pause(2)
                    capture("03-score-settings")
                    app.swipeDown(velocity: .fast)
                    pause(1)
                }
            }

            if tapIfExists(app.buttons["scoreMenuButton"]), tapIfExists(app.buttons["Modo Estudo"]) {
                // Let the engraved strip render in the web view
                pause(5)
                capture("04-practice")

                // Guided practice: playing the opening E5 D#5 E5 D#5 moves the score's cursor to the fifth note.
                // Für Elise goes down to A1, so its practice keyboard starts at C1 and the fifth E and D# from the left
                // are in octave 5.
                tapIfExists(app.buttons["practicePlayButton"])
                for name in ["E", "D#", "E", "D#"] {
                    tapKey(name, index: 4)
                    pause(0.6)
                }
                pause(2)
                capture("07-practice-progress")
                tapIfExists(app.buttons["Concluir"])
            }

            if tapIfExists(app.buttons["readingTrainerButton"]) {
                // Reading drill, right hand from the start: Für Elise opens with E5 D#5 E5
                pause(2)
                capture("14-reading")
                // A wrong key (G5) shows faintly where it would be written
                tapReadingKey("Sol", rightOf: "Dó5")
                pause(0.4)
                capture("15-reading-wrong")
                for name in ["Mi", "D#", "Mi"] {
                    tapReadingKey(name, rightOf: "Dó5")
                    pause(0.5)
                }
                pause(0.5)
                capture("16-reading-done")
                tapIfExists(app.buttons["readingLeftHand"])
                pause(1.5)
                capture("17-reading-left")
            }
        }

        // Element tree for fixing the walkthrough when a step above didn't find its element
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "ui-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    /// The first element whose label contains `text` (a card's texts may be merged into its button's label).
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func tapIfExists(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        element.tap()
        return true
    }

    /// Taps the `index`-th key (from the left) labelled `name` on the practice keyboard; the score screen's
    /// keyboard stays in the element tree behind the practice sheet, so the search is limited to the sheet's.
    private func tapKey(_ name: String, index: Int) {
        let keyboard = app.otherElements["practiceKeyboard"]
        guard keyboard.waitForExistence(timeout: 5) else { return }
        let keys = keyboard.staticTexts.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
            .sorted { $0.frame.minX < $1.frame.minX }
        guard index < keys.count else { return }
        keys[index].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Taps the first key labelled `name` to the right of the key labelled `anchor` on the reading drill's keyboard
    /// (its C keys show their octave, so "Dó5" finds the octave above middle C wherever the keyboard starts).
    private func tapReadingKey(_ name: String, rightOf anchor: String) {
        let keyboard = app.otherElements["readingKeyboard"]
        guard keyboard.waitForExistence(timeout: 5) else { return }
        let anchorKey = keyboard.staticTexts[anchor]
        guard anchorKey.waitForExistence(timeout: 2) else { return }
        let key = keyboard.staticTexts.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
            .filter { $0.frame.minX > anchorKey.frame.minX }
            .min { $0.frame.minX < $1.frame.minX }
        key?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        let predicate = NSPredicate(format: "label == %@", label)
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5)
    }

    private func pause(_ seconds: TimeInterval) {
        // The app runs in its own process, so sleeping the test runner just lets it settle
        Thread.sleep(forTimeInterval: seconds)
    }
}
