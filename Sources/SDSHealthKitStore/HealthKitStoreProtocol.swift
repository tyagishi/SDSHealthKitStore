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
}

/// public protocol for HealthKitStore
public protocol HealthKitStoreProtocol {
    /// Query result publisher
    var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>,HKStoreError> { get }

    init(_ healthStore: HKHealthStore?)
    
    var isHealthKit: Bool { get }
    
    /// retrieve authorization status
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus

    // request authorization
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                              read typeToRead: Set<HKObjectType>) async throws

    /// request sample query
    /// - Parameter type: query type
    /// - Returns: identifier for returned query result
    @discardableResult
    func retrieveSample(type: HKSampleType) -> UUID

    /// save samples
    ///
    /// HealthKit does not allow to update already existing element
    /// if you need to update, remove then create new one
    func saveSamples(_ samples: [HKSample]) async throws
    /// remove samples
    func deleteSamples(_ samples: [HKSample]) async throws
}

extension OSLog {
    //fileprivate static var mockLog = Logger(subsystem: "com.smalldesksoftware.weightclipneo", category: "mockHK")
    fileprivate static var mockLog = Logger(.disabled)
}

/// mock for HealthKitStore
public final class MockHealthKitStore: HealthKitStoreProtocol, HealthKitStoreProtocolInternal {
    public let fetchResult: PassthroughSubject<HKQueryResult<HKSample>,HKStoreError> = PassthroughSubject()
    public var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>, HKStoreError> {
        fetchResult.eraseToAnyPublisher()
    }
    
    internal var exportResult: PassthroughSubject<String, HKStoreError> = PassthroughSubject()
    public var exportPublisher: AnyPublisher<String, HKStoreError> {
        exportResult.eraseToAnyPublisher()
    }

    public var authStatus: HKAuthorizationStatus = .notDetermined
    public var data: [HKSample] = []
    
    public init(_ healthStore: HKHealthStore? = nil) {}

    public var isHealthKit: Bool { false }

    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        .sharingAuthorized
    }
    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                                     read typeToRead: Set<HKObjectType>) async throws {
        self.authStatus = .sharingAuthorized
    }
    
    public func retrieveSample(type: HKSampleType) -> UUID {
        OSLog.mockLog.debug("retrieveSample start")
        defer { OSLog.mockLog.debug("retrieveSample end") }
        let id = UUID()
        let sendData = data.filter({ $0.sampleType == type }).sorted(by: { $0.startDate > $1.startDate })
        fetchResult.send(HKQueryResult(id: id,
                                       type: type,
                                       results: sendData))
        return id
    }
    
    public func saveSamples(_ samples: [HKSample]) async throws {
        data.append(contentsOf: samples)
    }
    
    public func deleteSamples(_ samples: [HKSample]) async throws {
        data.removeAll(where: { samples.contains($0) })
    }
}
