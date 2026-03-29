//
//  ESP32BeltBLEDevice.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreBluetooth
import Combine

struct BeltBLEConstants {
    // TODO: Replace with manufacturer-specific UUIDs if available
    static let BeltServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let BeltRxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
}

struct ESP32BeltUARTService: BLEDeviceService {
    static var uuid = BeltBLEConstants.BeltServiceUUID
    static var characteristicUUIDs: [CBUUID] {
        return [BeltBLEConstants.BeltRxCharacteristicUUID]
    }
}

class ESP32BeltBLEDevice: BaseBLEDevice {
    override class var services: [BLEDeviceService.Type] {
        return [
            ESP32BeltUARTService.self,
            BLEDeviceInfoService.self,
            BLEBatteryLevelService.self
        ]
    }
    
    var rxCharacteristic: CBCharacteristic? {
        return characteristics[BeltBLEConstants.BeltRxCharacteristicUUID]
    }
    
    // Required initializer
    required convenience init(peripheral: CBPeripheral, delegate: BLEDeviceDelegate?) {
        self.init(peripheral: peripheral, type: .remote, delegate: delegate)
    }
    
    // Override onConnectionComplete
    override func onConnectionComplete() {
        super.onConnectionComplete()
        GDLogBLEInfo("ESP32BeltBLEDevice: Capabilities discovered and ready!")
    }
    
    // Write Data Function
    func write(data: Data) -> Bool {
        guard let rxChar = rxCharacteristic else {
            GDLogBLEError("ESP32BeltBLEDevice: TX failed - RX characteristic not found.")
            return false
        }
        
        let writeType: CBCharacteristicWriteType = rxChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        peripheral.writeValue(data, for: rxChar, type: writeType)
        return true
    }
}
