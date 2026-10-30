// WebLibraryScreenshotTests.swift
// luksMusicUITests
//
// Opens the online library (scores from luksmusic.web.app) as a guest and a public score with its original
// pages, attaching screenshots for the "App Store Screenshots" workflow. Runs after ScreenshotTests, so the
// guest session may already exist.

import XCTest

final class WebLibraryScreenshotTests: XCTestCase {

    private let app = XCUIApplication()

    func testOnlineLibraryPages() {
        app.launch()

        let guestButton = app.buttons["Continuar como Convidado (Offline)"]
        if guestButton.waitForExistence(timeout: 10) {
            guestButton.tap()
        }

        let onlineButton = app.buttons["onlineLibraryButton"]
        if onlineButton.waitForExistence(timeout: 15) {
            onlineButton.tap()

            // A short public-domain score (two pages) from the site's catalog
            let score = app.staticTexts["October (Autumn Song) – Tchaikovsky"]
            if score.waitForExistence(timeout: 40) {
                pause(1)
                capture("08-online-library")
                score.tap()

                // Pages come from the web, so give them time to download and draw
                pause(10)
                capture("09-online-score")

                let playButton = app.buttons["playPauseButton"]
                if playButton.waitForExistence(timeout: 5) {
                    playButton.tap()
                    pause(3)
                    playButton.tap()
                    pause(2)
                    capture("10-online-score-cursor")
                }
            } else {
                capture("08-online-library")
            }
        }

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "ui-tree-online"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        // The app runs in its own process, so sleeping the test runner just lets it settle
        Thread.sleep(forTimeInterval: seconds)
    }
}
