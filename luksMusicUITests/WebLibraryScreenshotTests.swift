// WebLibraryScreenshotTests.swift
// luksMusicUITests
//
// Downloads a public score of the luksmusic.web.app catalog from the library's catalog row as a guest and plays
// it in the score viewer, attaching screenshots for the "App Store Screenshots" workflow. Runs after
// ScreenshotTests, so the guest session may already exist.

import XCTest

final class WebLibraryScreenshotTests: XCTestCase {

    private let app = XCUIApplication()

    func testCatalogDownload() {
        app.launch()

        let guestButton = app.buttons["Continuar como Convidado (Offline)"]
        if guestButton.waitForExistence(timeout: 10) {
            guestButton.tap()
        }

        let playTab = app.tabBars.buttons["Tocar"]
        if playTab.waitForExistence(timeout: 15) {
            playTab.tap()
        }

        // A short public-domain piece (56 measures) from the site's catalog. Only its catalog card carries the
        // sidebar title with the composer; the downloaded copy in "Minhas partituras" is titled without it.
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "October (Autumn Song) – Tchaikovsky")).firstMatch
        if card.waitForExistence(timeout: 40) {
            // The row scrolls sideways and the catalog grows, so the card may start off screen
            var swipes = 0
            while card.frame.maxX > app.frame.maxX && swipes < 6 {
                let row = card.frame.midY / app.frame.height
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: row))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: row)))
                pause(0.7)
                swipes += 1
            }
            pause(1)
            capture("08-catalog")
            card.tap()

            // Downloaded into the library, then opened in the score viewer
            let playButton = app.buttons["playPauseButton"]
            if playButton.waitForExistence(timeout: 60) {
                // Let the engraved score render in the web view
                pause(5)
                capture("09-catalog-score")

                playButton.tap()
                pause(3)
                playButton.tap()
                pause(2)
                capture("10-catalog-score-cursor")

                for _ in 0..<2 {
                    let next = app.buttons["nextNoteButton"]
                    if next.exists { next.tap() }
                    pause(0.5)
                }
                pause(1)
                capture("12-catalog-score-steps")

                // Back in the library, the card says the score is on the phone
                let back = app.buttons["Voltar"].firstMatch
                if back.exists {
                    back.tap()
                    pause(2)
                    capture("44-catalog-downloaded")
                }
            } else {
                capture("09-catalog-download-failed")
            }
        } else {
            capture("08-catalog")
        }

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "ui-tree-catalog"
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
