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

public struct HKQueryResult<T:HKSample> {
    public let id: UUID
    public let type: HKSampleType
    public let results: [T]
}

internal protocol HealthKitStoreProtocolInternal {
    var fetchResult: PassthroughSubject<HKQueryResult<HKSample>,HKStoreError> { get }
    //var exportResult: PassthroughSubject<String,HKStoreError> { get }
}


public protocol HealthKitStoreProtocol {
    // for internal, "fetchResult" should be used instead
    var fetchPublisher: AnyPublisher<HKQueryResult<HKSample>,HKStoreError> { get }
    //var exportPublisher: AnyPublisher<String,HKStoreError> { get }

    init()
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>,
                              read typeToRead: Set<HKObjectType>) async throws

    @discardableResult
    func retrieveSample(type: HKSampleType) -> UUID

    func saveSamples(_ samples: [HKSample]) async throws
    func deleteSamples(_ samples: [HKSample]) async throws
}

extension OSLog {
    //fileprivate static var mockLog = Logger(subsystem: "com.smalldesksoftware.weightclipneo", category: "mockHK")
    fileprivate static var mockLog = Logger(.disabled)
}

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
    
    public init(){}

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
