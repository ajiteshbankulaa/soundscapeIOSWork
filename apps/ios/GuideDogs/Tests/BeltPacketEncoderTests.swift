//
//  BeltPacketEncoderTests.swift
//  SoundscapeTests
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

class BeltPacketEncoderTests: XCTestCase {

    func testNormalizeAzimuthFront() {
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 0, userHeading: 0)
        XCTAssertEqual(normalized, 0)
    }
    
    func testNormalizeAzimuthRight() {
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 90, userHeading: 0)
        XCTAssertEqual(normalized, 90)
    }
    
    func testNormalizeAzimuthLeft() {
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 0, userHeading: 90)
        XCTAssertEqual(normalized, 270)
    }
    
    func testNormalizeAzimuthBehind() {
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 180, userHeading: 360)
        XCTAssertEqual(normalized, 180)
    }
    
    func testNormalizeAzimuthWrapAroundPositive() {
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 350, userHeading: 10)
        XCTAssertEqual(normalized, 340)
    }

    func testNormalizeAzimuthWrapAroundNegative() {
        // Target is at bearing 10, user facing 350
        let normalized = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: 10, userHeading: 350)
        XCTAssertEqual(normalized, 20)
    }
    
    func testEncodeNavigationUpdate() {
        let encoded = BeltPacketEncoder.encodeNavigationUpdate(azimuth: 145, distance: 25)
        XCTAssertEqual(encoded, "AZIMUTH=145;DISTANCE_M=25\n")
    }
    
    func testEncodeIdleState() {
        let encoded = BeltPacketEncoder.encodeIdleState()
        XCTAssertEqual(encoded, "IDLE\n")
    }
}
