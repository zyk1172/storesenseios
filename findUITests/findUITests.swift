//
//  XiaoShouNaUITests.swift
//  XiaoShouNaUITests
//
//  Created by 郑云凯 on 2026/4/14.
//

import XCTest

final class XiaoShouNaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
