//
//  ViewController.swift
//  bikedatacollector2
//
//  Created by Thomas Lee on 7/10/16.
//  Copyright © 2016 Thomas Lee. All rights reserved.
//

import UIKit
import PocketSocket
import CoreLocation
import Firebase
import FirebaseDatabase

class ViewController: UIViewController, PSWebSocketServerDelegate, CLLocationManagerDelegate {
    
    var websocketServer: PSWebSocketServer!
    var location: CLLocationManager!
    var lastLocation: CLLocation?
    var ref: FIRDatabaseReference?
    var eventCount = 0
    var sessionName: String?
    
    @IBOutlet weak var serverOnlineLabel: UILabel!
    @IBOutlet weak var connectionActiveLabel: UILabel!
    @IBOutlet weak var GPSActiveLabel: UILabel!
    @IBOutlet weak var eventCountLabel: UILabel!
    
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

    @IBAction func switchWasToggled(sender: UISwitch) {
        if (sender.on) {
            self.websocketServer.start()
            self.location.startUpdatingLocation()
            self.eventCount = 0
            self.sessionName = ["bikedatacollector2", String(NSDate().timeIntervalSince1970).componentsSeparatedByString(".")[0]].joinWithSeparator("-")
        }
        else {
            self.sessionName = nil
            self.websocketServer.stop()
            self.location.stopUpdatingLocation()
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
        if let location = self.lastLocation {
            self.eventCount = self.eventCount + 1
            self.eventCountLabel.text = String(self.eventCount)
            
            if let sess = self.sessionName {
                if let coord = self.lastLocation {
                    print(sess)
                    print(coord)
                    self.ref!.child(sess).childByAutoId().setValue([
                        "timestamp": NSDate().timeIntervalSince1970,
                        "coord": [ coord.coordinate.longitude, coord.coordinate.latitude ],
                        "coordTimestamp": coord.timestamp.timeIntervalSince1970,
                        "horizontalAccuracy": coord.horizontalAccuracy,
                        "msg": message
                    ])
                }
            }
            
            print("\(location) - \(message)")
        }
        else {
            print("no location found \(message)")
        }
    }
    
    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: NSError!) {
    }
    
    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean:Bool) {
        self.connectionActiveLabel.textColor = UIColor.lightGrayColor()
    }
    
    // MARK: CLLocationManager delegate
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last
        if let coord = self.lastLocation?.coordinate {
            self.GPSActiveLabel.textColor = UIColor.blackColor()
            print("found location: \(coord.longitude), \(coord.latitude)")
        }
        else {
            self.GPSActiveLabel.textColor = UIColor.lightGrayColor()
        }
    }
    
}