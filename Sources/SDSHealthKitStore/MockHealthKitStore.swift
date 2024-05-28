//
//  MockHealthKitStore.swift
//
//  Created by : Tomoaki Yagishita on 2024/05/13
//  © 2024  SmallDeskSoftware
//

import Foundation
import Combine
import HealthKit
import OSLog

extension OSLog {
    //fileprivate static var mockLog = Logger(subsystem: "com.smalldesksoftware.weightclipneo", category: "MockHealthKitStore")
    fileprivate static var mockLog = Logger(.disabled)
}

/// mock for HealthKitStore
public final class MockHealthKitStore: HealthKitStoreProtocol, HealthKitStoreProtocolInternal {
    public let fetchResult: PassthroughSubject<HKQueryResult<HKSample>,HKStoreError> = PassthroughSubject()
    public var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>, HKStoreError> {
        fetchResult.eraseToAnyPublisher()
    }
    
    internal nonisolated let updateResult: PassthroughSubject<HKUpdatedSamples, HKStoreError> = PassthroughSubject()
    public nonisolated var updatePublisher: AnyPublisher<HKUpdatedSamples, HKStoreError> {
        updateResult.eraseToAnyPublisher()
    }

    public var types: Set<HKSampleType> = []
    public var data: [HKSample] = []
    let saveClosure: (([HKSample]) -> Void)?
    
    public init(_ healthStore: HKHealthStore? = nil, observeTypes: Set<HKSampleType> = []) {
        self.types = observeTypes
        self.saveClosure = nil
        Task { await startObservation(observeTypes) }
    }

    public init(_ healthStore: HKHealthStore? = nil,
                loadClosure: (() -> [HKSample]),
                saveClosure: (([HKSample]) -> Void)?) {
        self.data = loadClosure()
        self.saveClosure = saveClosure
    }

    public func startObservation(_ observeTypes: Set<HKSampleType>) async {
        for type in types {
            self.fetchResult.send(HKQueryResult(id: UUID(), type: type, results: data.filter({ $0.sampleType == type })))
            self.updateResult.send(HKUpdatedSamples(type: type, addedSamples: data.filter({  $0.sampleType == type }), deletedIDs: []))
        }
    }
    
    public var isHealthKit: Bool { false }

    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        .sharingAuthorized
    }

    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                                     read typeToRead: Set<HKObjectType>) async throws { }
    
    public func fetch(types: Set<HKSampleType>) async {
        for type in types {
            fetchResult.send(HKQueryResult(id: UUID(),
                                           type: type,
                                           results: data.filter({ $0.sampleType == type })))
        }
    }

    public func addSamples(_ samples: [HKSample]) async throws {
        data.append(contentsOf: samples)
        saveClosure?(data)
        var processSamples = samples
        while let sample = processSamples.first {
            fetchResult.send(HKQueryResult(id: UUID(), type: sample.sampleType,
                                           results: data.filter({ $0.sampleType == sample.sampleType })))
            updateResult.send(HKUpdatedSamples(type: sample.sampleType,
                                               addedSamples: data.filter({ $0.sampleType == sample.sampleType}),
                                               deletedIDs: []))
            processSamples = processSamples.filter({ $0.sampleType != sample.sampleType })
        }
    }
    
    public func replaceSample(_ oldSample: HKSample, with newSample: HKSample) async throws {
        try await deleteSamples([oldSample])
        try await addSamples([newSample])
    }

    public func deleteSamples(_ samples: [HKSample]) async throws {
        data.removeAll(where: { samples.contains($0) })
        saveClosure?(data)
        var processSamples = samples
        while let sample = processSamples.first {
            fetchResult.send(HKQueryResult(id: UUID(), type: sample.sampleType,
                                           results: data.filter({ $0.sampleType == sample.sampleType })))
            updateResult.send(HKUpdatedSamples(type: sample.sampleType,
                                               addedSamples: [],
                                               deletedIDs: samples.map({ ($0.uuid, nil) })))
            processSamples = processSamples.filter({ $0.sampleType != sample.sampleType })
        }
    }

    public func deleteAll(types: [HKSampleType]) async throws {
        data.removeAll(where: { types.contains($0.sampleType) })
        saveClosure?(data)

        var processTypes = types
        while let type = processTypes.first {
            fetchResult.send(HKQueryResult(id: UUID(), type: type,
                                           results: data.filter({ $0.sampleType == type })))
            processTypes = processTypes.filter({ $0 != type })
        }
    }
}
