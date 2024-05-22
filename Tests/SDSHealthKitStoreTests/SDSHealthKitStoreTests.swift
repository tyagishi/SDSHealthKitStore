import XCTest
@testable import SDSHealthKitStore

final class SDSHealthKitStoreTests: XCTestCase {
    
    func test_init_mock() async throws {
        let sut = MockHealthKitStore()
        XCTAssertNotNil(sut)
    }
    
    
}
