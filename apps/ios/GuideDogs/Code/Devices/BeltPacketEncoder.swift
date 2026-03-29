//
//  BeltPacketEncoder.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

struct BeltPacketEncoder {
    
    /// Normalizes azimuth from a given absolute bearing and user heading to 0-359.
    /// 0 = straight ahead, 90 = right, 180 = behind, 270 = left
    static func normalizeAzimuth(absoluteBearing: Double, userHeading: Double) -> Int {
        var relativeAzimuth = absoluteBearing - userHeading
        // Wrap to 0-360
        relativeAzimuth = fmod(relativeAzimuth, 360.0)
        if relativeAzimuth < 0 {
            relativeAzimuth += 360.0
        }
        return Int(round(relativeAzimuth)) % 360
    }
    
    /// Encodes navigation telemetry into the default ESP32 belt format.
    /// Expected format: "AZIMUTH=%d;DISTANCE_M=%d\n"
    static func encodeNavigationUpdate(azimuth: Int, distance: Int) -> String {
        return "AZIMUTH=\(azimuth);DISTANCE_M=\(distance)\n"
    }
    
    /// Encodes an idle packet to send when there is no target to navigate to.
    static func encodeIdleState() -> String {
        return "IDLE\n"
    }
}
