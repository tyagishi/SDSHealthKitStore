//
//  HealthKitProtocol.swift
//
//  Created by : Tomoaki Yagishita on 2024/04/27
//  © 2024  SmallDeskSoftware
//

import Foundation
import Combine
import HealthKit
import OSLog

public enum HKStoreError: Error {
    case errorInQuery(Error)
    case unexpectedNil
}

public struct HKUpdatedSamples {
    public let type: HKSampleType
    public let addedSamples: [HKSample]
    public let deletedIDs: [(uuid: UUID, metadata: [String:Any]?)]
}

/// query result type
///
/// HealthKitStore will provide query result via publisher
/// you can distinct a request result with using id from other request results
/// you can double check type info
///
public struct HKQueryResult<T:HKSample> {
    /// request id
    public let id: UUID
    // requested type
    public let type: HKSampleType
    // request result
    public let results: [T]
}

/// internal protocol for HealthKitStore
internal protocol HealthKitStoreProtocolInternal {
    var fetchResult: PassthroughSubject<HKQueryResult<HKSample>,HKStoreError> { get }
    var updateResult: PassthroughSubject<HKUpdatedSamples, HKStoreError> { get }

    // need to be deleted?
    func startObservation(_ observeTypes: Set<HKSampleType>) async
}

/// public protocol for HealthKitStore
public protocol HealthKitStoreProtocol {
    /// Query result publisher
    var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>,HKStoreError> { get }
    var updatePublisher: AnyPublisher<HKUpdatedSamples, HKStoreError> { get }

    init(_ healthStore: HKHealthStore?, observeTypes: Set<HKSampleType>)
    
    var isHealthKit: Bool { get }
    
    /// retrieve authorization status
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus

    // request authorization
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                              read typeToRead: Set<HKObjectType>) async throws


    /// fetch
    func fetch(types: Set<HKSampleType>) async

    /// add sample
    func addSamples(_ samples: [HKSample]) async throws

    /// replace sample
    func replaceSample(_ oldSample: HKSample, with newSample: HKSample) async throws

    /// remove samples
    func deleteSamples(_ samples: [HKSample]) async throws
    
    /// remove all
    func deleteAll(types: [HKSampleType]) async throws
}

