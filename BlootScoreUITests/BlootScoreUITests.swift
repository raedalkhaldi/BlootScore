import XCTest

final class BlootScoreUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    func testFullFlow() throws {
        // شاشة 1: الإعداد - اضغط ابدأ
        Thread.sleep(forTimeInterval: 1)
        let startBtn = app.buttons["ابدأ اللعبة"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 3))
        startBtn.tap()
        Thread.sleep(forTimeInterval: 1)
        
        // شاشة 2: لوحة النقاط - اضغط جولة جديدة
        let newRound = app.buttons["جولة جديدة"]
        XCTAssertTrue(newRound.waitForExistence(timeout: 3))
        newRound.tap()
        Thread.sleep(forTimeInterval: 1)
    }
}
