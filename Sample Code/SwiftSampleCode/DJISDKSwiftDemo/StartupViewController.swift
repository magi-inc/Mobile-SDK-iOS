//
//  StartupViewController.swift
//  DJISDKSwiftDemo
//
//  Created by DJI on 11/13/15.
//  Copyright © 2015 DJI. All rights reserved.
//

import UIKit
import DJISDK
import Foundation
import CoreLocation

class StartupViewController: UIViewController, UITextFieldDelegate {

    weak var appDelegate: AppDelegate! = UIApplication.shared.delegate as? AppDelegate
    
    @IBOutlet weak var productConnectionStatus: UILabel!
    @IBOutlet weak var productModel: UILabel!
    @IBOutlet weak var productFirmwarePackageVersion: UILabel!
    @IBOutlet weak var sdkVersionLabel: UILabel!
    @IBOutlet weak var bridgeModeLabel: UILabel!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.resetUI()
        
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        
        latitudeTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        longitudeTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        latitudeTextField.keyboardType = .decimalPad
        longitudeTextField.keyboardType = .decimalPad
        
        addDoneButtonToKeyboard()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.height
            
            // Move the view up if necessary
            self.view.frame.origin.y = -keyboardHeight / 2
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        // Reset the view's position
        self.view.frame.origin.y = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let connectedKey = DJIProductKey(param: DJIParamConnection) else {
            NSLog("Error creating the connectedKey")
            return;
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { 
            DJISDKManager.keyManager()?.startListeningForChanges(on: connectedKey, withListener: self, andUpdate: { (oldValue: DJIKeyedValue?, newValue : DJIKeyedValue?) in
                if newValue != nil {
                    if newValue!.boolValue {
                        // At this point, a product is connected so we can show it.
                        
                        // UI goes on MT.
                        DispatchQueue.main.async {
                            self.productConnected()
                        }
                    }
                }
            })
            DJISDKManager.keyManager()?.getValueFor(connectedKey, withCompletion: { (value:DJIKeyedValue?, error:Error?) in
                if let unwrappedValue = value {
                    if unwrappedValue.boolValue {
                        // UI goes on MT.
                        DispatchQueue.main.async {
                            self.productConnected()
                        }
                    }
                }
            })
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        DJISDKManager.keyManager()?.stopAllListening(ofListeners: self)
    }
    
    func addDoneButtonToKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissKeyboard))
        toolbar.setItems([doneButton], animated: false)

        latitudeTextField.inputAccessoryView = toolbar
        longitudeTextField.inputAccessoryView = toolbar
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        guard let lat = latitudeTextField.text, let lon = longitudeTextField.text else { return }
        
        flyToCoordinates(lat: Float(lat), lon: Float(lon))
    }
    
    @objc func textFieldDidChange() {
        if let latitude = latitudeTextField.text, let longitude = longitudeTextField.text, !latitude.isEmpty && !longitude.isEmpty {
            sendButton.isEnabled = true
        } else {
            sendButton.isEnabled = false
        }
    }
    
    func resetUI() {
        self.title = "DJI iOS SDK Sample"
        self.sdkVersionLabel.text = "DJI SDK Version: \(DJISDKManager.sdkVersion())"
        self.longitudeTextField.text = ""
        self.latitudeTextField.text = ""
        self.sendButton.isEnabled = false;
        self.productModel.isHidden = true
        self.productFirmwarePackageVersion.isHidden = true
        self.bridgeModeLabel.isHidden = !self.appDelegate.productCommunicationManager.enableBridgeMode
        
        if self.appDelegate.productCommunicationManager.enableBridgeMode {
            self.bridgeModeLabel.text = "Bridge: \(self.appDelegate.productCommunicationManager.bridgeAppIP)"
        }
    }
    
    func showAlert(_ msg: String?) {
        // create the alert
        let alert = UIAlertController(title: "", message: msg, preferredStyle: UIAlertController.Style.alert)
        // add the actions (buttons)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK : Product connection UI changes
    
    func productConnected() {
        guard let newProduct = DJISDKManager.product() else {
            NSLog("Product is connected but DJISDKManager.product is nil -> something is wrong")
            return;
        }

        //Updates the product's model
        self.productModel.text = "Model: \((newProduct.model)!)"
        self.productModel.isHidden = false
        
        //Updates the product's firmware version - COMING SOON
        newProduct.getFirmwarePackageVersion{ (version:String?, error:Error?) -> Void in
            
            self.productFirmwarePackageVersion.text = "Firmware Package Version: \(version ?? "Unknown")"
            
            if let _ = error {
                self.productFirmwarePackageVersion.isHidden = true
            }else{
                self.productFirmwarePackageVersion.isHidden = false
            }
            
            NSLog("Firmware package version is: \(version ?? "Unknown")")
        }
        
        //Updates the product's connection status
        self.productConnectionStatus.text = "Status: Product Connected"
        NSLog("Product Connected")
    }
    
    func productDisconnected() {
        self.productConnectionStatus.text = "Status: No Product Connected"
        NSLog("Product Disconnected")
    }
    
    func flyToCoordinates(lat: Float?, lon: Float?) {
        guard let lat = lat, let lon = lon else { return }
        
        let telem = Telemetry()
        telem.startMonitoringDroneState()

        guard let pos = telem.getLatestState()?.aircraftLocation else { return }

        let angle = calculateBearing(start: pos, end: CLLocation(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon)))

        guard let aircraft = DJISDKManager.product() as? DJIAircraft else {
            print("The connected product is not an aircraft.")
            return
        }

        guard let flightController = aircraft.flightController else {
            print("Flight controller not available.")
            return
        }

        if !flightController.isVirtualStickControlModeAvailable() {
            print("Virtual Stick mode is not available on this drone.")
            return
        }

        flightController.setVirtualStickModeEnabled(true)

        // Set the control modes
        self.configureControlModes(for: flightController)

        flightController.send(DJIVirtualStickFlightControlData(pitch:0, roll:0, yaw:Float(angle), verticalThrottle:0))

    //        flightController.send(DJIVirtualStickFlightControlData(pitch:0, roll:0, yaw:Float(angle), verticalThrottle:0), withCompletion: <#T##DJICompletionBlock?##DJICompletionBlock?##((any Error)?) -> Void#>)

        while true {
            guard let location = telem.getLatestState()?.aircraftLocation else { return }

            let distance = calculateDistance(pointA: location.coordinate, pointB: CLLocationCoordinate2D(latitude: Double(lat), longitude: Double(lon)))
            if distance < 1 {return} // less than 1 meter

            flightController.send(DJIVirtualStickFlightControlData(pitch: 5, roll: 0, yaw: 0, verticalThrottle: 0))
        }
    }

    func calculateDistance(pointA: CLLocationCoordinate2D, pointB: CLLocationCoordinate2D) -> Double {
        // Create CLLocation objects for both points
        let locationA = CLLocation(latitude: pointA.latitude, longitude: pointA.longitude)
        let locationB = CLLocation(latitude: pointB.latitude, longitude: pointB.longitude)

        // Calculate the distance in meters
        let distance = locationA.distance(from: locationB)

        return distance
    }

    private func configureControlModes(for flightController: DJIFlightController) {
        // Set roll and pitch control to velocity
        flightController.rollPitchControlMode = .velocity
        print("Roll and Pitch control mode set to velocity.")

        // Set yaw control to angular velocity
        flightController.yawControlMode = .angle
        print("Yaw control mode set to angular velocity.")

        // Set vertical control to velocity
        flightController.verticalControlMode = .velocity
        print("Vertical control mode set to velocity.")

        // Set roll and pitch coordinate system to ground
        flightController.rollPitchCoordinateSystem = .ground
        print("Roll and Pitch coordinate system set to ground.")

        print("Control modes configured successfully.")
    }

    func calculateBearing(start: CLLocation, end: CLLocation) -> Double {
        let startLatitude = toRadians(coord: start.coordinate.latitude)
        let startLongitude = toRadians(coord: start.coordinate.longitude)
        let endLatitude = toRadians(coord: end.coordinate.latitude)
        let endLongitude = toRadians(coord: end.coordinate.longitude)

        let deltaLongitude = endLongitude - startLongitude

        let y = sin(deltaLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(deltaLongitude)

        let initialBearing = toDegrees(coord: atan2(y, x))

        // Normalize to 0-360
        return (initialBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    func toRadians(coord: CLLocationDegrees) -> Double {
        return coord * .pi / 180
    }

    func toDegrees(coord: CLLocationDegrees) -> Double {
        return coord * 180 / .pi
    }
}



