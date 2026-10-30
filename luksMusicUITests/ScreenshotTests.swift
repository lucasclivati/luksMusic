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
            tapIfExists(app.buttons["drawerToggleButton"])

            if tapIfExists(app.buttons["scoreSettingsButton"]) {
                let keyboardToggle = app.switches["displayKeyboardToggle"]
                if keyboardToggle.waitForExistence(timeout: 5) {
                    pause(1)
                    capture("03-score-settings")
                    keyboardToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
                    pause(1)
                }
                app.swipeDown(velocity: .fast)
                pause(1)
            }

            playButton.tap()
            pause(4)
            playButton.tap()
            pause(1)
            capture("02-score")

            if tapIfExists(app.buttons["practiceModeButton"]) {
                pause(3)
                capture("04-practice")
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

    private func pause(_ seconds: TimeInterval) {
        // The app runs in its own process, so sleeping the test runner just lets it settle
        Thread.sleep(forTimeInterval: seconds)
    }
}
