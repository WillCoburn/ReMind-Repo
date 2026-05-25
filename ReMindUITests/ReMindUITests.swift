//
//  ReMindUITests.swift
//  ReMindUITests
//
//  Created by Will Coburn on 9/15/25.
//

import XCTest
import UIKit

final class ReMindUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testMainViewActionLayoutForCurrentDynamicType() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-BrainMailDebugScreen", "main"]
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))

        let sendNow = app.buttons["home.action.Send One Now"]
        let fullPDF = app.buttons["home.action.Full PDF"]
        let inspirationBank = app.buttons["home.action.Inspiration Bank"]
        let help = app.buttons["home.action.Help"]

        scrollUntilHittable(help, in: scrollView)

        XCTAssertTrue(sendNow.exists)
        XCTAssertTrue(fullPDF.exists)
        XCTAssertTrue(inspirationBank.exists)
        XCTAssertTrue(help.exists)

        let usesWrappedActionGrid = inspirationBank.frame.midY - sendNow.frame.midY > 44
        if usesWrappedActionGrid {
            assertAligned(sendNow.frame.midY, fullPDF.frame.midY, tolerance: 28, "Top action row should align")
            assertAligned(inspirationBank.frame.midY, help.frame.midY, tolerance: 28, "Bottom action row should align")
            XCTAssertGreaterThan(inspirationBank.frame.midY - sendNow.frame.midY, 44)
            assertAligned(sendNow.frame.midX, inspirationBank.frame.midX, tolerance: 34, "Left action column should align")
            assertAligned(fullPDF.frame.midX, help.frame.midX, tolerance: 34, "Right action column should align")
        } else {
            let rowMidY = sendNow.frame.midY
            [fullPDF, inspirationBank, help].forEach {
                assertAligned(rowMidY, $0.frame.midY, tolerance: 28, "Compact actions should stay in one row")
            }
        }

        [sendNow, fullPDF, inspirationBank, help].forEach {
            XCTAssertGreaterThanOrEqual($0.frame.minX, app.frame.minX - 1)
            XCTAssertLessThanOrEqual($0.frame.maxX, app.frame.maxX + 1)
        }

        let compactComposer = app.descendants(matching: .any)["home.entryComposer.compact"]
        scrollUntilTappable(compactComposer, in: scrollView, app: app, direction: .down)
        XCTAssertTrue(compactComposer.isHittable)
        compactComposer.tap()

        let editor = app.textViews["home.entryTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
    }

    func testNewEntryComposerOpensAndClosesReliably() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-BrainMailDebugScreen", "main"]
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))

        let compactComposer = app.descendants(matching: .any)["home.entryComposer.compact"]
        scrollUntilTappable(compactComposer, in: scrollView, app: app)
        XCTAssertTrue(compactComposer.isHittable)

        compactComposer.tap()

        let editor = app.textViews["home.entryTextEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
        editor.typeText("Testing the new composer")

        let cancel = app.buttons["home.entryComposer.overlay.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.tap()

        XCTAssertTrue(compactComposer.waitForExistence(timeout: 4))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 4)

        scrollUntilTappable(compactComposer, in: scrollView, app: app)
        compactComposer.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 4))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
        editor.typeText(" again")
    }

    func testHelpSheetScrollsWithinBoundsForCurrentDynamicType() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-BrainMailDebugScreen", "main"]
        app.launch()

        let mainScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(mainScrollView.waitForExistence(timeout: 8))

        let helpButton = app.buttons["home.action.Help"]
        scrollUntilHittable(helpButton, in: mainScrollView)
        XCTAssertTrue(helpButton.isHittable)
        helpButton.tap()

        XCTAssertTrue(app.staticTexts["A guide to BrainMail"].waitForExistence(timeout: 10))

        let helpScrollView = app.scrollViews["help.scroll"]
        XCTAssertTrue(helpScrollView.waitForExistence(timeout: 5))

        let supportTitle = app.staticTexts["Support/contact"]
        scrollUntilVisible(supportTitle, in: helpScrollView, app: app, maxAttempts: 24)

        XCTAssertTrue(supportTitle.exists)
        XCTAssertTrue(app.frame.intersects(supportTitle.frame))
        XCTAssertGreaterThanOrEqual(supportTitle.frame.minX, app.frame.minX - 1)
        XCTAssertLessThanOrEqual(supportTitle.frame.maxX, app.frame.maxX + 1)
    }

    func testInspirationBankModalContentWithLargeDynamicType() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BrainMailDebugScreen", "main",
            "-UIPreferredContentSizeCategoryName", UIContentSizeCategory.accessibilityExtraExtraLarge.rawValue
        ]
        app.launch()

        let mainScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(mainScrollView.waitForExistence(timeout: 8))

        let inspirationBank = app.buttons["home.action.Inspiration Bank"]
        scrollUntilHittable(inspirationBank, in: mainScrollView)
        XCTAssertTrue(inspirationBank.isHittable)
        inspirationBank.tap()

        XCTAssertTrue(app.staticTexts["Borrow some inspiration"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Add anything that you'd want to receive later."].exists)
        XCTAssertFalse(app.staticTexts["Philosophers"].exists)

        let categoryTabs = app.scrollViews["inspiration.categoryTabs"]
        XCTAssertTrue(categoryTabs.waitForExistence(timeout: 5))

        let categoryIDs = [
            "Eastern Philosophy",
            "Writers & Poets",
            "Stoicism",
            "Christian",
            "Discipline",
            "Mindfulness",
            "Anxiety & overthinking",
            "Self-worth",
            "Developer's favorites"
        ]
        for categoryID in categoryIDs {
            XCTAssertTrue(app.buttons["inspiration.category.\(categoryID)"].exists)
        }

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inspiration.add.eastern-philosophy-")).firstMatch.waitForExistence(timeout: 5))
    }

    func testPhoneSignupConsentGatingWithLargeDynamicType() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BrainMailDebugScreen", "onboarding",
            "-UIPreferredContentSizeCategoryName", UIContentSizeCategory.accessibilityExtraExtraLarge.rawValue
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome in."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your number is only used for verification and your BrainMail texts."].exists)

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertFalse(continueButton.isEnabled)

        let phoneField = app.textFields.firstMatch
        XCTAssertTrue(phoneField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.intersects(phoneField.frame))
        phoneField.tap()
        phoneField.typeText("4155551234")
        XCTAssertFalse(continueButton.isEnabled)

        let scrollView = app.scrollViews.firstMatch
        let consentButton = app.buttons["I agree to receive text messages from BrainMail."]
        XCTAssertTrue(consentButton.waitForExistence(timeout: 5))
        scrollUntilHittable(consentButton, in: scrollView)
        XCTAssertTrue(consentButton.isHittable)
        consentButton.tap()

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: continueButton)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(app.staticTexts["Reply STOP to opt out, HELP for support."].exists)
        XCTAssertTrue(app.links["Terms"].exists)
        XCTAssertTrue(app.links["Privacy"].exists)
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        direction: ScrollDirection = .up,
        maxAttempts: Int = 8
    ) {
        for _ in 0..<maxAttempts {
            if element.exists && element.isHittable { return }
            switch direction {
            case .up:
                scrollView.swipeUp()
            case .down:
                scrollView.swipeDown()
            }
        }
    }

    private func scrollUntilTappable(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication,
        direction: ScrollDirection = .up,
        maxAttempts: Int = 8
    ) {
        for _ in 0..<maxAttempts {
            if element.exists && element.isHittable && app.frame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                return
            }
            switch direction {
            case .up:
                scrollView.swipeUp()
            case .down:
                scrollView.swipeDown()
            }
        }
    }

    private func scrollHorizontallyUntilHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        maxAttempts: Int = 10
    ) {
        for _ in 0..<maxAttempts {
            if element.exists && element.isHittable { return }
            scrollView.swipeLeft()
        }
    }

    private func scrollUntilVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication,
        direction: ScrollDirection = .up,
        maxAttempts: Int = 10
    ) {
        for _ in 0..<maxAttempts {
            if element.exists && app.frame.intersects(element.frame) { return }
            switch direction {
            case .up:
                let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
                let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
                start.press(forDuration: 0.02, thenDragTo: end)
            case .down:
                let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
                let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
                start.press(forDuration: 0.02, thenDragTo: end)
            }
        }
    }

    private func assertAligned(
        _ lhs: CGFloat,
        _ rhs: CGFloat,
        tolerance: CGFloat,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(abs(lhs - rhs), tolerance, message, file: file, line: line)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
