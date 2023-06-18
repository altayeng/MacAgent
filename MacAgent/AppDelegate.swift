//
//  AppDelegate.swift
//  MacAgent
//
//  Created by Altay Kırlı on 16.06.2023.
//

import Cocoa
import LaunchAtLogin
import CocoaMQTT

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var windowController: NSWindowController?
    var mqtt: CocoaMQTT!
    var timer: Timer?



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        LaunchAtLogin.isEnabled = true
        if let button = statusItem.button {
            button.title = "F"
        }
        startMQTTTimer()

        NSApplication.shared.windows.last!.close()
    }
 
    

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func startMQTTTimer() {
        // Timer'ı her 30 saniyede bir tetiklemek için scheduledTimer kullanıyoruz
        timer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(setupMQTT), userInfo: nil, repeats: true)
        
        // Timer'ı başlatıyoruz
        timer?.fire()
    }
    
    @objc func setupMQTT() {
        let clientID = "HiveMQ" // MQTT istemci kimliği
        
        mqtt = CocoaMQTT(clientID: clientID, host: "mqtt-dashboard.com", port: 1883) // MQTT sunucu bilgileri
        mqtt.didConnectAck = { mqtt, ack in
            if ack == .accept {
                print("MQTT sunucusuna başarıyla bağlandı.")
                self.subscribeToTopic()
            } else {
                print("MQTT sunucusuna bağlantı başarısız.")
            }
        }
        
        mqtt.didReceiveMessage = { mqtt, message, id in
            print("Status: \(message.string!)")
            
            if message.string == "on" {
                self.statusItem.button?.title = "O" // Menü adını "O" olarak değiştir
            } else if message.string == "off" {
                self.statusItem.button?.title = "F" // Menü adını "F" olarak değiştir
            }
        }
        
        mqtt.keepAlive = 60
        mqtt.connect()
    }

    func subscribeToTopic() {
        let topic = "MacAgent" // Abone olmak istediğiniz MQTT konusu
        
        mqtt.subscribe(topic)
        print("Konuya abone olundu: \(topic)")
    }


}

