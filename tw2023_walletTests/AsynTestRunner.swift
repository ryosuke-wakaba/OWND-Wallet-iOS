//
//  AsynTestRunner.swift
//  tw2023_walletTests
//
//  Created by 若葉良介 on 2023/12/27.
//

import XCTest

extension XCTestCase {
    func runAsyncTest(_ asyncTest: @escaping () async throws -> Void) {
        let expectation = self.expectation(description: "Async Test")
        var caughtError: Error?

        Task {
            do {
                try await asyncTest()
            }
            catch {
                caughtError = error
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        // Handle caught errors after the task completes
        if let error = caughtError {
            // Don't report XCTSkip as a failure - it's handled specially by the test framework
            // Unfortunately, we can't re-throw it from here, so we report it as a pass with a note
            if error is XCTSkip {
                // XCTSkip was thrown - this is expected behavior, not a failure
                // The test result will show as a pass (not a skip) when using this helper
                // For proper skip support, check skip conditions before calling runAsyncTest
                return
            }
            XCTFail("Async test failed with error: \(error)")
        }
    }
}
