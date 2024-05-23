//
//  SDSHealthKitStore_MockTests.swift
//
//  Created by : Tomoaki Yagishita on 2024/05/22
//  © 2024  SmallDeskSoftware
//

import XCTest
import HealthKit
@testable import SDSHealthKitStore

final class SDSHealthKitStore_MockTests: XCTestCase {
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    
    let sut: MockHealthKitStore = MockHealthKitStore()
    
    override func setUp() async throws {
        try await sut.deleteAll(types: [bodyMassType, bodyFatType])
    }
    
    func test_init() async throws {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.data.count, 0)
    }
    
    func test_add_delete_oneSample() async throws {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date, end: date)
        try await sut.addSamples([bodyMassSample])
        
        XCTAssertEqual(sut.data.count, 1)
        let massSample = try XCTUnwrap(sut.data[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        try await sut.deleteSamples([bodyMassSample])
        XCTAssertEqual(sut.data.count, 0)
    }
    
    func test_add_twoMassSample() async throws {
        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)

        try await sut.addSamples([bodyMassSample1, bodyMassSample2])
        
        XCTAssertEqual(sut.data.count, 2)
    }
    
    func test_add_replaceSample() async throws {
        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        try await sut.addSamples([bodyMassSample1])
        XCTAssertEqual(sut.data.count, 1)

        var massSample = try XCTUnwrap(sut.data[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date1)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)
        try await sut.replaceSample(bodyMassSample1, with: bodyMassSample2)
        XCTAssertEqual(sut.data.count, 1)

        massSample = try XCTUnwrap(sut.data[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date2)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 83.1)
    }
}
