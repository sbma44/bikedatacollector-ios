//
//  ViewController.swift
//  bikedatacollector2
//
//  Created by Thomas Lee on 7/10/16.
//  Copyright © 2016 Thomas Lee. All rights reserved.
//

import UIKit
import AudioToolbox
import PocketSocket
import CoreLocation
import Firebase
import FirebaseDatabase



class ViewController: UIViewController, PSWebSocketServerDelegate, CLLocationManagerDelegate {
    
    
    public func server(_ server: PSWebSocketServer!, didFailWithError error: Error!) {
    }

    
    var websocketServer: PSWebSocketServer!
    var location: CLLocationManager!
    var ref: FIRDatabaseReference?
    var eventCount = 0
    var sessionName: String?
    var firstEvent: Bool! = true
    
    var maxCM = 300.0
    
    @IBOutlet weak var serverOnlineLabel: UILabel!
    @IBOutlet weak var connectionActiveLabel: UILabel!
    @IBOutlet weak var GPSActiveLabel: UILabel!
    @IBOutlet weak var eventCountLabel: UILabel!
    @IBOutlet weak var runNameLabel: UILabel!
    @IBOutlet weak var distanceBar1: UIProgressView!
    @IBOutlet weak var distanceBar2: UIProgressView!
    
    override func viewDidLoad() {
        self.websocketServer = PSWebSocketServer(host:nil, port:8000)
        self.websocketServer.delegate = self
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        if (authStatus != CLAuthorizationStatus.denied) && (authStatus != CLAuthorizationStatus.restricted) {
            
            self.location = CLLocationManager()
            self.location.delegate = self
            
            if authStatus == CLAuthorizationStatus.notDetermined {
                self.location.requestAlwaysAuthorization()
            }
            
            self.location.desiredAccuracy = kCLLocationAccuracyBest
        }
        
        self.ref = FIRDatabase.database().reference()
        
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonWasPressed(_ sender: UIButton) {
        if self.sessionName == nil {
            sender.setTitle("Stop Run", for: UIControlState())
            sender.backgroundColor = UIColor.red
            UIApplication.shared.isIdleTimerDisabled = true
            FIRDatabase.database().goOffline() // cache collected data, don't sync in realtime
            self.websocketServer.start()
            self.location.startUpdatingLocation()
            self.eventCount = 0
            self.firstEvent = true
            
            let dayTimePeriodFormatter = DateFormatter()
            dayTimePeriodFormatter.dateFormat = "yMMdd-HHmmss"
            
            self.sessionName = ["bd2", dayTimePeriodFormatter.string(from: Date())].joined(separator: "-")
            self.runNameLabel.text = self.sessionName
            self.runNameLabel.textColor = UIColor.black
        }
        else {
            sender.setTitle("Start Run", for: UIControlState())
            sender.backgroundColor = self.view.tintColor
            self.runNameLabel.textColor = UIColor.lightGray
            self.sessionName = nil
            self.firstEvent = false
            self.websocketServer.stop()
            self.location.stopUpdatingLocation()
            FIRDatabase.database().goOnline()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: PSWebSocketServerDelegate
    func serverDidStart(_ server: PSWebSocketServer!) {
        self.serverOnlineLabel.textColor = UIColor.black
        print("started websocket server")
    }
    
    func serverDidStop(_ server: PSWebSocketServer!) {
        self.serverOnlineLabel.textColor = UIColor.lightGray
        print("stopped websocket server")
    }
    
    func server(_ server: PSWebSocketServer!, acceptWebSocketWith request: URLRequest!) -> Bool {
        return true
    }
    
    func server(_ server: PSWebSocketServer!, webSocketDidOpen webSocket: PSWebSocket!) {
        self.connectionActiveLabel.textColor = UIColor.black
    }
    
    func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didReceiveMessage message: Any!) {
        self.eventCount = self.eventCount + 1
        self.eventCountLabel.text = String(self.eventCount)
        
        if self.firstEvent! {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            self.firstEvent = false
        }
        
        if let sess = self.sessionName {
            self.ref!.child(sess).childByAutoId().setValue([
                "timestamp": Date().timeIntervalSince1970,
                "msg": message
            ])
            
            print(">>> " + String(describing: message))
            
            if String(describing: message).range(of: "/") != nil {
                if let distance = Double(String(describing: message).components(separatedBy: "/")[1]) {
                    self.distanceBar1.progress = Float(distance / self.maxCM)
                }
                if let distance = Double(String(describing: message).components(separatedBy: "/")[2]) {
                    self.distanceBar2.progress = Float(distance / self.maxCM)
                }
            }
            else if String(describing: message).range(of: "RANGE") != nil {
                if let range = Double(String(describing: message).components(separatedBy: ":")[1]) {
                    print("Detected max sensor range as \(self.maxCM)cm")
                    self.maxCM = range
                }
            }
        }
    }
    
    func connectionFail() {
        for _ in 1...2 {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
    }
    
    func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: Error!) {
        connectionFail()
    }
    
    func server(_ server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean:Bool) {
        connectionFail()
        self.connectionActiveLabel.textColor = UIColor.lightGray
    }
    
    // MARK: CLLocationManager delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc:CLLocation = locations.last! {
            let coord = loc.coordinate
            
            self.GPSActiveLabel.textColor = UIColor.black
            print("found location: \(coord.longitude), \(coord.latitude)")
            
            if let sess = self.sessionName {
                self.ref!.child(sess).childByAutoId().setValue([
                    "timestamp": Date().timeIntervalSince1970,
                    "coord": [ coord.longitude, coord.latitude ],
                    "coordTimestamp": loc.timestamp.timeIntervalSince1970,
                    "horizontalAccuracy": loc.horizontalAccuracy,
                    "speed": loc.speed
                ])
            }
        }
        else {
            self.GPSActiveLabel.textColor = UIColor.lightGray
        }
    }
    
}
