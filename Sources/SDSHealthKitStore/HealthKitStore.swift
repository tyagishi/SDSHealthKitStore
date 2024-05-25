//
//  HealthKitStore.swift
//
//  Created by : Tomoaki Yagishita on 2024/04/27
//  © 2024  SmallDeskSoftware
//

import Foundation
import Combine
import HealthKit
import OSLog

// MARK:
// NSHealthShareUsageDescription    for reading
// NSHealthUpdateUsageDescription   for saving

extension OSLog {
    fileprivate static var log = Logger(subsystem: "com.smalldesksoftware.weightclipneo", category: "HealthKitStore")
    //fileprivate static var log = Logger(.disabled)
}


/// HealthKitStore(actor)
///
/// no sync method to retrieve samples.
/// need to sink publisher to receive query result
/// 
public actor HealthKitStore: HealthKitStoreProtocol, HealthKitStoreProtocolInternal {
    nonisolated internal let fetchResult: PassthroughSubject<HKQueryResult,HKStoreError> = PassthroughSubject()
    nonisolated public var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>, HKStoreError> {
        fetchResult.eraseToAnyPublisher()
    }
    
    nonisolated internal let updateResult: PassthroughSubject<HKUpdatedSamples, HKStoreError> = PassthroughSubject()
    nonisolated public var updatePublisher: AnyPublisher<HKUpdatedSamples, HKStoreError> {
        updateResult.eraseToAnyPublisher()
    }
    
    var anchor: HKQueryAnchor? = nil
    
    let healthStore: HKHealthStore
    
    var queries: [HKQuery] = []

    // note: this predicate is constant value, will not make any data races
    let allSamplePredicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date.distantFuture)
    
    public init(_ healthStore: HKHealthStore?, observeTypes: Set<HKSampleType> = []) {
        guard let healthStore = healthStore else { fatalError("invalid argument")}
        self.healthStore = healthStore
        Task { await startObservation(observeTypes) }
    }
    
    public func startObservation(_ observeTypes: Set<HKSampleType> = []) {
        queries.removeAll()
        for type in observeTypes {
            // note: unclear about callback condition for resultHandler/updateHandler
            let ancQuery = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit,
                                                 resultsHandler: { (query, samplesOrNil, deletedOrNil, newAnchor, errorOrNil) in
                guard let addedSamples = samplesOrNil,
                      let deletedSamples = deletedOrNil else {
                    if let error = errorOrNil { OSLog.log.error("\(error)"); return }
                    OSLog.log.error("error in HKAnchoredObjectQuery")
                    return
                }
                self.anchor = newAnchor
                guard !addedSamples.isEmpty || !deletedSamples.isEmpty else { return }
                self.updateResult.send(HKUpdatedSamples(type: type,
                                                        addedSamples: addedSamples,
                                                        deletedIDs: deletedSamples.map({ ($0.uuid, $0.metadata) })))
                OSLog.log.debug("HKAnchoredObjectQuery(type: \(type)) called, send add: \(addedSamples.count), del: \(deletedSamples.count) samples")
            })
            ancQuery.updateHandler = { (query, samplesOrNil, deletedOrNil, newAnchor, errorOrNil) in
                guard let addedSamples = samplesOrNil,
                      let deletedSamples = deletedOrNil else {
                    if let error = errorOrNil { OSLog.log.error("\(error)"); return }
                    OSLog.log.error("error in HKAnchoredObjectQuery")
                    return
                }
                self.anchor = newAnchor
                guard !addedSamples.isEmpty || !deletedSamples.isEmpty else { return }
                self.updateResult.send(HKUpdatedSamples(type: type,
                                                        addedSamples: addedSamples, deletedIDs: deletedSamples.map({ ($0.uuid, $0.metadata) })))
                OSLog.log.debug("HKAnchoredObjectQuery.update(type: \(type)) called, send add: \(addedSamples.count), del: \(deletedSamples.count) samples")
            }
            queries.append(ancQuery)
            healthStore.execute(ancQuery)
            /// Note: will be called when app became foreground too
            let obsQuery = HKObserverQuery(sampleType: type, predicate: nil, updateHandler: { (query, completion, error) in
                if let error = error { OSLog.log.error("\(error)"); return }
                Task {
                    let samples = await self.querySamples(type)
                    self.fetchResult.send(HKQueryResult(id: UUID(), type: type, results: samples))
                    OSLog.log.debug("observerQuery(type: \(type)) called, send \(samples.count) samples")
                }
                completion()
            })
            queries.append(obsQuery)
            healthStore.execute(obsQuery)
        }
    }

    public func fetch(types: Set<HKSampleType>) async {
        OSLog.log.debug(#function)
        for type in types {
            let samples = await self.querySamples(type)
            self.fetchResult.send(HKQueryResult(id: UUID(), type: type, results: samples))
        }
    }

    func querySamples(_ type: HKSampleType) async -> [HKSample] {
        return await withCheckedContinuation { continuation in
            let typeDescriptor = HKQueryDescriptor(sampleType: type, predicate: nil)
            let query = HKSampleQuery(queryDescriptors: [typeDescriptor], limit: Int(HKObjectQueryNoLimit)) { (query, samples, error) in
                if let error = error {
                    print("\(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else if let samples = samples {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            self.healthStore.execute(query)
        }
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
    
    public func addSamples(_ samples: [HKSample]) async throws {
        try await healthStore.save(samples)
    }
    
    public func replaceSample(_ oldSample: HKSample, with newSample: HKSample) async throws {
        try await deleteSamples([oldSample])
        try await addSamples([newSample])
    }

    public func deleteSamples(_ samples: [HKSample]) async throws {
        try await healthStore.delete(samples)
    }
    
    public func deleteAll(types: [HKSampleType]) async throws {
        for type in types {
            try await healthStore.deleteObjects(of: type,
                                                predicate: allSamplePredicate)
        }
    }
}
