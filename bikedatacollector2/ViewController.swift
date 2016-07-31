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
        
        if (authStatus != CLAuthorizationStatus.Denied) && (authStatus != CLAuthorizationStatus.Restricted) {
            
            self.location = CLLocationManager()
            self.location.delegate = self
            
            if authStatus == CLAuthorizationStatus.NotDetermined {
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

    @IBAction func buttonWasPressed(sender: UIButton) {
        if self.sessionName == nil {
            sender.setTitle("Stop Run", forState: UIControlState.Normal)
            sender.backgroundColor = UIColor.redColor()
            UIApplication.sharedApplication().idleTimerDisabled = true
            FIRDatabase.database().goOffline() // cache collected data, don't sync in realtime
            self.websocketServer.start()
            self.location.startUpdatingLocation()
            self.eventCount = 0
            self.firstEvent = true
            
            let dayTimePeriodFormatter = NSDateFormatter()
            dayTimePeriodFormatter.dateFormat = "yMMdd-HHmmss"
            
            self.sessionName = ["bd2", dayTimePeriodFormatter.stringFromDate(NSDate())].joinWithSeparator("-")
            self.runNameLabel.text = self.sessionName
            self.runNameLabel.textColor = UIColor.blackColor()
        }
        else {
            sender.setTitle("Start Run", forState: UIControlState.Normal)
            sender.backgroundColor = self.view.tintColor
            self.runNameLabel.textColor = UIColor.lightGrayColor()
            self.sessionName = nil
            self.firstEvent = false
            self.websocketServer.stop()
            self.location.stopUpdatingLocation()
            FIRDatabase.database().goOnline()
            UIApplication.sharedApplication().idleTimerDisabled = false
        }
    }
    
    // MARK: PSWebSocketServerDelegate
    func serverDidStart(server: PSWebSocketServer!) {
        self.serverOnlineLabel.textColor = UIColor.blackColor()
        print("started websocket server")
    }
    
    func server(server: PSWebSocketServer!, didFailWithError: NSError!) {
        print(didFailWithError)
    }
    
    func serverDidStop(server: PSWebSocketServer!) {
        self.serverOnlineLabel.textColor = UIColor.lightGrayColor()
        print("stopped websocket server")
    }
    
    func server(server: PSWebSocketServer!, acceptWebSocketWithRequest request: NSURLRequest!) -> Bool {
        return true
    }
    
    func server(server: PSWebSocketServer!, webSocketDidOpen webSocket: PSWebSocket!) {
        self.connectionActiveLabel.textColor = UIColor.blackColor()
    }
    
    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didReceiveMessage message: AnyObject!) {
        self.eventCount = self.eventCount + 1
        self.eventCountLabel.text = String(self.eventCount)
        
        if self.firstEvent! {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            self.firstEvent = false
        }
        
        if let sess = self.sessionName {
            self.ref!.child(sess).childByAutoId().setValue([
                "timestamp": NSDate().timeIntervalSince1970,
                "msg": message
            ])
            
            print(">>> " + String(message))
            
            if String(message).rangeOfString("/") != nil {
                if let distance = Double(String(message).componentsSeparatedByString("/")[1]) {
                    self.distanceBar1.progress = Float(distance / self.maxCM)
                }
                if let distance = Double(String(message).componentsSeparatedByString("/")[2]) {
                    self.distanceBar2.progress = Float(distance / self.maxCM)
                }
            }
            else if String(message).rangeOfString("RANGE") != nil {
                if let range = Double(String(message).componentsSeparatedByString(":")[1]) {
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
    
    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: NSError!) {
        connectionFail()
    }
    
    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean:Bool) {
        connectionFail()
        self.connectionActiveLabel.textColor = UIColor.lightGrayColor()
    }
    
    // MARK: CLLocationManager delegate
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc:CLLocation = locations.last! {
            let coord = loc.coordinate
            
            self.GPSActiveLabel.textColor = UIColor.blackColor()
            print("found location: \(coord.longitude), \(coord.latitude)")
            
            if let sess = self.sessionName {
                self.ref!.child(sess).childByAutoId().setValue([
                    "timestamp": NSDate().timeIntervalSince1970,
                    "coord": [ coord.longitude, coord.latitude ],
                    "coordTimestamp": loc.timestamp.timeIntervalSince1970,
                    "horizontalAccuracy": loc.horizontalAccuracy
                ])
            }
        }
        else {
            self.GPSActiveLabel.textColor = UIColor.lightGrayColor()
        }
    }
    
}