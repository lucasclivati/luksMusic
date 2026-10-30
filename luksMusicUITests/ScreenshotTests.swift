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

        let furElise = app.staticTexts["Für Elise (Bagatelle No. 25)"]
        if furElise.waitForExistence(timeout: 15) {
            pause(1)
            capture("01-library")
            furElise.tap()
        }

        let playButton = app.buttons["playPauseButton"]
        if playButton.waitForExistence(timeout: 15) {
            // Let the engraved score render in the web view
            pause(5)
            playButton.tap()
            waitForLabel(playButton, "Pausar")
            pause(1)
            playButton.tap()
            waitForLabel(playButton, "Tocar")
            // Back to the first measure so the title and the opening notes are on screen
            for _ in 0..<4 {
                tapIfExists(app.buttons["Compasso anterior"])
            }
            pause(2)
            capture("02-score")

            if tapIfExists(app.buttons["scoreMenuButton"]) {
                pause(1)
                capture("06-score-menu")
                if tapIfExists(app.buttons["menuSettingsButton"]) {
                    pause(2)
                    capture("03-score-settings")
                    app.swipeDown(velocity: .fast)
                    pause(1)
                }
            }

            if tapIfExists(app.buttons["scoreMenuButton"]), tapIfExists(app.buttons["menuPracticeButton"]) {
                // Let the engraved strip render in the web view
                pause(5)
                capture("04-practice")

                // Guided practice: playing the opening E5 D#5 E5 D#5 moves the score's cursor to the fifth note.
                // Für Elise's practice keyboard starts at C2, so the fourth E and D# from the left are in octave 5.
                tapIfExists(app.buttons["practicePlayButton"])
                for name in ["E", "D#", "E", "D#"] {
                    tapKey(name, index: 3)
                    pause(0.6)
                }
                pause(2)
                capture("07-practice-progress")
                tapIfExists(app.buttons["Done"])
            }
        }

        // Element tree for fixing the walkthrough when a step above didn't find its element
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "ui-tree"
        tree.lifetime = .keepAlways
        add(tree)
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

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        let predicate = NSPredicate(format: "label == %@", label)
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5)
    }

    private func pause(_ seconds: TimeInterval) {
        // The app runs in its own process, so sleeping the test runner just lets it settle
        Thread.sleep(forTimeInterval: seconds)
    }
}
