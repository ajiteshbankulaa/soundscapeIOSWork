//
//  ESP32BeltDevice.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import Combine
import CoreBluetooth

enum ESP32BeltDeviceStatus: Int, Equatable, Comparable {
    case unknown
    case disconnected
    case connecting
    case ready

    static func < (lhs: ESP32BeltDeviceStatus, rhs: ESP32BeltDeviceStatus) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class ESP32BeltDevice: NSObject, Device {
    static let DEVICE_MODEL_NAME: String = GDLocalizationUnnecessary("ESP32 Vibration Belt")
    
    // Attributes
    private let queue: OperationQueue
    private var bleBelt: ESP32BeltBLEDevice?
    private var connectionTimer: Timer?
    private let connectionTimeOutSeconds: Double = 30.0
    
    private(set) var status: CurrentValueSubject<ESP32BeltDeviceStatus, Never>
    
    // Device attributes
    let model = ESP32BeltDevice.DEVICE_MODEL_NAME
    let type: DeviceType = .esp32VibrationBelt
    
    var isFirstConnection: Bool = true
    
    var isConnected: Bool {
        if let belt = bleBelt {
            return belt.state == .ready
        }
        return false
    }
    
    var name: String {
        return bleBelt?.peripheral.name ?? _nameDummy
    }
    
    var id: UUID {
        return bleBelt?.peripheral.identifier ?? _idDummy
    }
    
    private var _idDummy: UUID
    private var _nameDummy: String
    private weak var _deviceDelegate: DeviceDelegate?
    
    var deviceDelegate: DeviceDelegate? {
        get { return _deviceDelegate }
        set { _deviceDelegate = newValue }
    }
    
    // Initializers
    convenience init(id: UUID, name: String) {
        self.init()
        self._idDummy = id
        self._nameDummy = name
    }
    
    override init() {
        self._idDummy = UUID()
        self._nameDummy = ""
        queue = OperationQueue()
        queue.name = "ESP32BeltUpdatesQueue"
        queue.qualityOfService = .userInteractive
        status = .init(.unknown)
        super.init()
    }
    
    static func setupDevice(callback: @escaping DeviceCompletionHandler) {
        GDLogAppInfo("Belt: SetupDevice")
        let device = ESP32BeltDevice()
        callback(.success(device))
        device.connect()
    }
    
    func connect() {
        guard bleBelt == nil else {
            GDLogAppInfo("Belt: Connecting Belt, but already connected.")
            return
        }
        
        GDLogBLEInfo("Belt: Starting scan for ESP32BeltBLEDevice")
        AppContext.shared.bleManager.startScan(for: ESP32BeltBLEDevice.self, delegate: self)
        status.value = .connecting
        
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeOutSeconds, repeats: false) { [weak self] timer in
            self?.queue.addOperation {
                GDLogBLEError("Belt: Connection timed out!")
                self?.connectionTimer?.invalidate()
                self?.connectionTimer = nil
                
                AppContext.shared.bleManager.stopScan()
                self?.status.value = .disconnected
                if let s = self {
                    s.deviceDelegate?.didFailToConnectDevice(s, error: DeviceError.failedConnection)
                }
            }
        }
    }
    
    func disconnect() {
        GDLogAppInfo("Belt: Disconnect called")
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        if let belt = bleBelt {
            AppContext.shared.bleManager.cancelConnection(belt, notify: false)
        }
        
        status.value = .disconnected
        bleBelt = nil
        deviceDelegate?.didDisconnectDevice(self)
    }
    
    func sendNavigationUpdate(azimuth: Double, distance: Double, rawPayload: String) {
        guard isConnected, let bleBelt = bleBelt else { return }
        guard let data = rawPayload.data(using: .utf8) else {
            GDLogBLEError("Belt: Failed to encode payload string to data.")
            return
        }
        
        // Let BeltNavigationStreamManager handle throttling/spam prevention
        let success = bleBelt.write(data: data)
        if !success {
            GDLogBLEError("Belt: Packet stream send failed.")
        }
    }
}

// MARK: BLEManagerScanDelegate & BLEDeviceDelegate
extension ESP32BeltDevice: BLEManagerScanDelegate, BLEDeviceDelegate {
    func onDeviceStateChanged(_ device: BLEDevice) {
        let oldManagerStatus = self.status.value
        
        switch device.state {
        case .unknown:
            self.status.value = .unknown
            
        case .disconnecting:
            GDLogBLEInfo("Belt: BLEDevice is disconnecting")
            
        case .disconnected:
            GDLogBLEInfo("Belt: BLEDevice is .disconnected")
            self.status.value = .disconnected
            if oldManagerStatus > .disconnected {
                self.disconnect()
            }
            
        case .initializing:
            GDLogBLEInfo("Belt: BLEDevice is initializing")
            AppContext.shared.bleManager.stopScan()
            self.status.value = .connecting
            
        case .ready:
            GDLogBLEInfo("Belt: BLEDevice is ready")
            connectionTimer?.invalidate()
            connectionTimer = nil
            
            self.status.value = .ready
            self.deviceDelegate?.didConnectDevice(self)
            
            self.isFirstConnection = false
        }
    }
    
    func onDeviceNameChanged(_ device: BLEDevice, _ name: String) {
        // no-op
    }
    
    func onDevicesChanged(_ discovered: [BLEDevice]) {
        guard bleBelt == nil else { return }
        
        for device in discovered {
            if let beltDevice = device as? ESP32BeltBLEDevice {
                GDLogBLEInfo("Belt: BLEManager discovered belt. Caching reference.")
                AppContext.shared.bleManager.stopScan()
                self.bleBelt = beltDevice
                if self.status.value == .unknown {
                    self.status.value = .disconnected
                }
                
                // Connect
                beltDevice.delegate = self
                AppContext.shared.bleManager.connect(beltDevice)
                break
            }
        }
    }
    
    func onError(_ error: Error) {
        GDLogBLEError("Belt: BLE error \(error.localizedDescription)")
    }
    
    func didConnect(_ device: BLEDevice) {
        onDeviceStateChanged(device)
    }
    
    func didUpdate(_ device: BLEDevice, name: String?) {
        // No-op for now
    }
}
