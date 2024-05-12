//
//  HealthKitStore.swift
//
//  Created by : Tomoaki Yagishita on 2024/04/27
//  © 2024  SmallDeskSoftware
//

import Foundation
import Combine
import HealthKit

// MARK:
// NSHealthShareUsageDescription    for reading
// NSHealthUpdateUsageDescription   for saving

/// HealthKitStore(actor)
///
/// no sync method to retrieve samples.
/// need to sink publisher to receive query result
/// 
public actor HealthKitStore: HealthKitStoreProtocol, HealthKitStoreProtocolInternal {
    internal let fetchResult: PassthroughSubject<HKQueryResult,HKStoreError> = PassthroughSubject()
    public nonisolated var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>, HKStoreError> {
        fetchResult.eraseToAnyPublisher()
    }
    
    let healthStore: HKHealthStore
    
    public init(_ healthStore: HKHealthStore?) {
        guard let healthStore = healthStore else { fatalError("invalid argument")}
        self.healthStore = healthStore
    }

    nonisolated public var isHealthKit: Bool { true }

    nonisolated static public var healthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                                     read typeToRead: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typeToRead)
    }
    
    nonisolated public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }
    
    nonisolated public func retrieveSample(type: HKSampleType) -> UUID {
        let id = UUID()
        let sortDesc = NSSortDescriptor(key: "startDate", ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil,
                                  limit: Int(HKObjectQueryNoLimit),
                                  sortDescriptors: [sortDesc]) { (query, samples, error) in
            if let error = error {
                self.fetchResult.send(completion: .failure(.errorInQuery(error)))
            } else {
                if let samples = samples {
                    self.fetchResult.send(HKQueryResult(id: id, type: type, results: samples))
                } else {
                    self.fetchResult.send(completion: .failure(.unexpectedNil))
                }
            }
        }
        self.healthStore.execute(query)
        return id
    }
    
    nonisolated public func saveSamples(_ samples: [HKSample]) async throws {
        try await healthStore.save(samples)
    }
    
    nonisolated public func deleteSamples(_ samples: [HKSample]) async throws {
        try await healthStore.delete(samples)
    }
}
