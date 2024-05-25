//
//  SDSHealthKitStore_MockPublisherTests.swift
//
//  Created by : Tomoaki Yagishita on 2024/05/25
//  © 2024  SmallDeskSoftware
//

import XCTest
import Combine
import HealthKit
@testable import SDSHealthKitStore

final class SDSHealthKitStore_MockPublisherTests: XCTestCase {
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    
    let sut: MockHealthKitStore = MockHealthKitStore()
    
    var cancellables: Set<AnyCancellable> = Set()
    
    override func setUp() async throws {
        try await sut.deleteAll(types: [bodyMassType])
    }
    
    func test_init() async throws {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.data.count, 0)
    }
    
    func test_add_delete_oneSample_viaUpdate() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        let expectation2 = expectation(description: "update")
        expectation2.expectedFulfillmentCount = 2
        expectation2.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.updatePublisher.sink(receiveCompletion: { error in
        }, receiveValue: { update in
            let ids = update.deletedIDs.map({ $0.uuid })
            samples.removeAll(where: { ids.contains($0.uuid) })
            samples.append(contentsOf: update.addedSamples)
            expectation1.fulfill()
            expectation2.fulfill()
        }).store(in: &cancellables)
        
        await sut.startObservation([bodyMassType])
        
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date, end: date)
        try await sut.addSamples([bodyMassSample])
        
        await fulfillment(of: [expectation1], timeout: 5)
        
        XCTAssertEqual(samples.count, 1)
        let massSample = try XCTUnwrap(sut.data[0] as? HKQuantitySample)
        XCTAssertEqual(massSample.startDate, date)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        try await sut.deleteSamples([bodyMassSample])
        await fulfillment(of: [expectation2], timeout: 5)
        XCTAssertEqual(samples.count, 0)
    }
    
    func test_add_twoMassSample_viaUpdate() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.updatePublisher.sink(receiveCompletion: { error in
        }, receiveValue: { update in
            let ids = update.deletedIDs.map({ $0.uuid })
            samples.removeAll(where: { ids.contains($0.uuid) })
            samples.append(contentsOf: update.addedSamples)
            expectation1.fulfill()
        }).store(in: &cancellables)
        await sut.startObservation([bodyMassType])

        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)

        try await sut.addSamples([bodyMassSample1, bodyMassSample2])
        await fulfillment(of: [expectation1], timeout: 5)

        XCTAssertEqual(samples.count, 2)
    }
    
    func test_add_replaceSample_viaUpdate() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        let expectation2 = expectation(description: "update")
        expectation2.expectedFulfillmentCount = 3 // remove and add
        expectation2.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.updatePublisher.sink(receiveCompletion: { error in
        }, receiveValue: { update in
            let ids = update.deletedIDs.map({ $0.uuid })
            samples.removeAll(where: { ids.contains($0.uuid) })
            samples.append(contentsOf: update.addedSamples)
            expectation1.fulfill()
            expectation2.fulfill()
        }).store(in: &cancellables)
        await sut.startObservation([bodyMassType])

        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        try await sut.addSamples([bodyMassSample1])
        await fulfillment(of: [expectation1], timeout: 5)
        XCTAssertEqual(samples.count, 1)

        var massSample = try XCTUnwrap(samples[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date1)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)
        try await sut.replaceSample(bodyMassSample1, with: bodyMassSample2)
        await fulfillment(of: [expectation2], timeout: 5)
        XCTAssertEqual(samples.count, 1)

        massSample = try XCTUnwrap(samples[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date2)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 83.1)
    }
    
    func test_add_delete_oneSample_viaFetch() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        let expectation2 = expectation(description: "update")
        expectation2.expectedFulfillmentCount = 2
        expectation2.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.fetchPublisher.sink(receiveCompletion: { error in
        }, receiveValue: { fetch in
            samples = fetch.results
            expectation1.fulfill()
            expectation2.fulfill()
        }).store(in: &cancellables)
        await sut.startObservation([bodyMassType])

        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date, end: date)
        try await sut.addSamples([bodyMassSample])
        
        await fulfillment(of: [expectation1], timeout: 5)
        
        XCTAssertEqual(samples.count, 1)
        let massSample = try XCTUnwrap(sut.data[0] as? HKQuantitySample)
        XCTAssertEqual(massSample.startDate, date)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        try await sut.deleteSamples([bodyMassSample])
        await fulfillment(of: [expectation2], timeout: 5)
        XCTAssertEqual(samples.count, 0)
    }
    
    func test_add_twoMassSample_viaFetch() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.fetchPublisher.sink(receiveCompletion: { error in
        }, receiveValue: { fetch in
            samples = fetch.results
            expectation1.fulfill()
        }).store(in: &cancellables)
        await sut.startObservation([bodyMassType])

        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)

        try await sut.addSamples([bodyMassSample1, bodyMassSample2])
        await fulfillment(of: [expectation1], timeout: 5)

        XCTAssertEqual(samples.count, 2)
    }
    
    func test_add_replaceSample_viaFetch() async throws {
        let expectation1 = expectation(description: "update")
        expectation1.expectedFulfillmentCount = 1
        expectation1.assertForOverFulfill = false
        let expectation2 = expectation(description: "update")
        expectation2.expectedFulfillmentCount = 3 // remove and add
        expectation2.assertForOverFulfill = false
        
        var samples: [HKSample] = []
        
        sut.fetchPublisher.sink(receiveCompletion: { error in
        }, receiveValue: { fetch in
            samples = fetch.results
            expectation1.fulfill()
            expectation2.fulfill()
        }).store(in: &cancellables)
        await sut.startObservation([bodyMassType])

        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 9, minute: 0, second: 0))!
        let bodyMassSample1 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 81.2),
                                              start: date1, end: date1)
        try await sut.addSamples([bodyMassSample1])
        await fulfillment(of: [expectation1], timeout: 5)
        XCTAssertEqual(samples.count, 1)

        var massSample = try XCTUnwrap(samples[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date1)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 81.2)
        
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 21, minute: 0, second: 0))!
        let bodyMassSample2 = HKQuantitySample(type: bodyMassType, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 83.1),
                                              start: date2, end: date2)
        try await sut.replaceSample(bodyMassSample1, with: bodyMassSample2)
        await fulfillment(of: [expectation2], timeout: 5)
        XCTAssertEqual(samples.count, 1)

        massSample = try XCTUnwrap(samples[0] as? HKQuantitySample)
        
        XCTAssertEqual(massSample.startDate, date2)
        XCTAssertEqual(massSample.quantityType, bodyMassType)
        XCTAssertEqual(massSample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 83.1)
    }
}
