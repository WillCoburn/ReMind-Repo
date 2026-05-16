//
//  ReMindUITests.swift
//  ReMindUITests
//
//  Created by Will Coburn on 9/15/25.
//

import XCTest

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

        let expectsAccessibilityGrid = ProcessInfo.processInfo.environment["EXPECT_ACCESSIBILITY_GRID"] == "1"
        if expectsAccessibilityGrid {
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

        scrollUntilHittable(app.textViews["home.entryTextEditor"], in: scrollView, direction: .down)
        let editor = app.textViews["home.entryTextEditor"]
        XCTAssertTrue(editor.isHittable)
        editor.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
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
