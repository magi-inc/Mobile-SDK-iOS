//
//  Telemetry.swift
//  DJISDKSwiftDemo
//
//  Created by Kevin Wang on 2024-11-16.
//  Copyright © 2024 DJI. All rights reserved.
//

class Telemetry: NSObject, DJIFlightControllerDelegate {

    private var latestState: DJIFlightControllerState?

    func startMonitoringDroneState() {
        guard let aircraft = DJISDKManager.product() as? DJIAircraft else {
            print("The connected product is not an aircraft.")
            return
        }

        guard let flightController = aircraft.flightController else {
            print("Flight controller not available.")
            return
        }

        // Set this class as the delegate
        flightController.delegate = self
        print("Monitoring drone state...")
    }

    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        // Save the state
        self.latestState = state

        print("Drone Altitude: \(state.altitude) meters")
    }

    // Method to retrieve the latest state
    func getLatestState() -> DJIFlightControllerState? {
        return latestState
    }
}
