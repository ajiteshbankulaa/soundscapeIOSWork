//
//  BeltNavigationStreamManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import Combine

class BeltNavigationStreamManager {
    
    private let telemetryThrottlingInterval: TimeInterval = 0.2 // 5 Hz
    private var telemetryTimer: Timer?
    
    private var isStreamingActive = false
    private var lastSentAzimuth: Int?
    private var lastSentDistance: Int?
    
    private var connectedBelt: ESP32BeltDevice? {
        return AppContext.shared.deviceManager.devices.first(where: { ($0 as? ESP32BeltDevice)?.isConnected == true }) as? ESP32BeltDevice
    }
    
    // Observers
    private var destinationChangedObserver: NSObjectProtocol?
    private var routeGuidanceObserver: NSObjectProtocol?
    private var deviceConnectedObserver: NSObjectProtocol?
    private var deviceDisconnectedObserver: NSObjectProtocol?
    
    private var appStateCancellable: AnyCancellable?
    
    init() {
        setupObservers()
    }
    
    deinit {
        stopStreaming()
        removeObservers()
    }
    
    // MARK: - State Management
    
    private func setupObservers() {
        // App lifecycle / Operation state
        appStateCancellable = NotificationCenter.default.publisher(for: Notification.Name.appOperationStateDidChange).sink { [weak self] notification in
            guard let state = notification.userInfo?[AppContext.Keys.operationState] as? OperationState else { return }
            if state != .normal {
                self?.stopStreaming()
                self?.sendIdlePacket()
            } else {
                self?.evaluateStreamingState()
            }
        }
        
        // Navigation / Destination
        destinationChangedObserver = NotificationCenter.default.addObserver(forName: Notification.Name.destinationChanged, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateStreamingState()
        }
        
        routeGuidanceObserver = NotificationCenter.default.addObserver(forName: Notification.Name.routeGuidanceStateChanged, object: nil, queue: .main) { [weak self] _ in
            self?.evaluateStreamingState()
        }
        
        // Device connection
        deviceConnectedObserver = NotificationCenter.default.addObserver(forName: Notification.Name.bluetoothDidUpdateState, object: nil, queue: .main) { [weak self] _ in
            // Fallback evaluating when state changes broadly since DeviceManager delegate might not broadcast general connect outside of devices menu quickly enough
            self?.evaluateStreamingState()
        }
    }
    
    private func removeObservers() {
        if let ob = destinationChangedObserver { NotificationCenter.default.removeObserver(ob) }
        if let ob = routeGuidanceObserver { NotificationCenter.default.removeObserver(ob) }
        if let ob = deviceConnectedObserver { NotificationCenter.default.removeObserver(ob) }
        if let ob = deviceDisconnectedObserver { NotificationCenter.default.removeObserver(ob) }
        appStateCancellable?.cancel()
    }
    
    func evaluateStreamingState() {
        // Ensure belt is connected
        guard let _ = connectedBelt else {
            stopStreaming()
            return
        }
        
        // Check if there is an active navigation target
        let hasDestination = AppContext.shared.spatialDataContext.destinationManager.isDestinationSet
        let hasRoute = AppContext.shared.isRouteGuidanceActive
        
        if hasDestination || hasRoute {
            startStreaming()
        } else {
            stopStreaming()
            sendIdlePacket()
        }
    }
    
    // MARK: - Streaming
    
    private func startStreaming() {
        guard !isStreamingActive else { return }
        GDLogAppInfo("Belt Stream: Starting")
        isStreamingActive = true
        lastSentAzimuth = nil
        lastSentDistance = nil
        
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: telemetryThrottlingInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopStreaming() {
        guard isStreamingActive else { return }
        GDLogAppInfo("Belt Stream: Stopping")
        isStreamingActive = false
        telemetryTimer?.invalidate()
        telemetryTimer = nil
    }
    
    private func tick() {
        guard let belt = connectedBelt, isStreamingActive else {
            stopStreaming()
            return
        }
        
        let geoManager = AppContext.shared.geolocationManager
        guard let userLocation = geoManager.location else { return }
        
        // Get user heading explicitly (ordered by .user)
        let headingValue = geoManager.heading(orderedBy: [.user, .device, .course]).value ?? 0.0
        
        // Find target location
        var targetLocation: CLLocation?
        
        if AppContext.shared.isRouteGuidanceActive {
            if let behavior = AppContext.shared.eventProcessor.activeBehavior as? RouteGuidance {
                if let waypoint = behavior.currentWaypoint?.waypoint {
                    targetLocation = waypoint.source.closestLocation(from: userLocation, useEntranceIfAvailable: true)
                }
            }
        } else if AppContext.shared.spatialDataContext.destinationManager.isDestinationSet {
            targetLocation = AppContext.shared.spatialDataContext.destinationManager.destination?.closestLocation(from: userLocation)
        }
        
        guard let target = targetLocation else {
            return
        }
        
        // Compute distance and azimuth
        let absoluteBearing = userLocation.bearing(to: target)
        let distance = Int(round(userLocation.distance(from: target)))
        let azimuth = BeltPacketEncoder.normalizeAzimuth(absoluteBearing: absoluteBearing, userHeading: headingValue)
        
        // Throttle identical packets if values haven't changed to save bandwidth, unless 1s has passed perhaps?
        // Let's just stream blindly at 5Hz as required for continuous telemetry
        // Or we can log every 10th packet
        
        let payload = BeltPacketEncoder.encodeNavigationUpdate(azimuth: azimuth, distance: distance)
        
        let diffAzi = abs((lastSentAzimuth ?? -999) - azimuth)
        let diffDist = abs((lastSentDistance ?? -999) - distance)
        
        if diffAzi > 5 || diffDist > 2 || lastSentAzimuth == nil {
            var logPacket = true
            #if !DEBUG
            logPacket = false // Silence noisy console in release
            #endif
            
            if logPacket {
                GDLogBLEVerbose("Belt Stream: Sending Azimuth: \(azimuth), Distance: \(distance)")
            }
            
            lastSentAzimuth = azimuth
            lastSentDistance = distance
        }
        
        belt.sendNavigationUpdate(azimuth: Double(azimuth), distance: Double(distance), rawPayload: payload)
    }
    
    private func sendIdlePacket() {
        if let belt = connectedBelt {
            GDLogBLEInfo("Belt Stream: Sending IDLE state")
            belt.sendNavigationUpdate(azimuth: 0, distance: 0, rawPayload: BeltPacketEncoder.encodeIdleState())
        }
    }
}
