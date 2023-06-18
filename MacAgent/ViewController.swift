//
//  ViewController.swift
//  MacAgent
//
//  Created by Altay Kırlı on 16.06.2023.
//

import Cocoa
import AVFoundation
import CocoaMQTT //81. satır görsel gösterme

class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var mqtt: CocoaMQTT!
    var captureOutput: AVCapturePhotoOutput!
    var timer: Timer?

    @IBOutlet weak var yeniden: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startMQTTTimer()
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    @IBAction func yeniden(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Yeniden Deneniyor"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }
    
    func startMQTTTimer() {
        // Timer'ı her 30 saniyede bir tetiklemek için scheduledTimer kullanıyoruz
        timer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(setupMQTT), userInfo: nil, repeats: true)
        
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
            print("Message received: \(message.string!)")
            
            if message.string == "on" {
                self.openCamera()
            } else if message.string == "off" {
                self.closeCamera()
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
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Kamera cihazı bulunamadı.")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            // AVCapturePhotoOutput'ı oluştur
            let photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                captureOutput = photoOutput // captureOutput değişkenini güncelle
            }
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer.videoGravity = .resizeAspectFill
            videoPreviewLayer.frame = view.bounds
           // view.layer?.addSublayer(videoPreviewLayer)
            
            captureSession.startRunning()
        } catch {
            print("Kamera girişi oluşturulamadı: \(error.localizedDescription)")
        }
    }

    
    func openCamera() {
            setupCamera()
            sleep(1)
            capturePhoto()
    }
    
    func closeCamera() {
        if captureSession != nil && captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Görüntüyü işlemek için istediğiniz kodu buraya yazabilirsiniz.
        // Örneğin, görüntüyü alıp kullanıcı arayüzünde göstermek için şu şekilde yapabilirsiniz:
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            DispatchQueue.main.async {
                // NSImageView öğesini kullanarak görüntüyü göster
                let imageView = NSImageView(frame: self.view.bounds)
                imageView.image = nsImage
                self.view.addSubview(imageView)
            }
        }
    }
    
    func capturePhoto() {
        guard let captureOutput = self.captureOutput else {
            print("Capture output is not available.")
            return
        }
        
        // Otomatik pozlama ayarlarını yapmak için AVCapturePhotoSettings'i kullanıyoruz
        let photoSettings = AVCapturePhotoSettings()
        
        // Otomatik pozlama modunu etkinleştiriyoruz
        if let currentCamera = AVCaptureDevice.default(for: .video) {
            if currentCamera.isExposureModeSupported(.continuousAutoExposure) {
                try? currentCamera.lockForConfiguration()
                currentCamera.exposureMode = .continuousAutoExposure
                currentCamera.unlockForConfiguration()
            }
        }
        
        captureOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    
    
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(), let image = NSImage(data: imageData) else {
            print("Failed to convert photo data to image.")
            return
        }
        
        // Fotoğraf verisini al
        guard let imageTiffData = image.tiffRepresentation else {
            print("Failed to get TIFF representation of the image.")
            return
        }
        
        // TIFF verisini JPEG olarak sıkıştır
        guard let jpegData = NSBitmapImageRep(data: imageTiffData)?.representation(using: .jpeg, properties: [:]) else {
            print("Failed to compress image to JPEG format.")
            return
        }
        
        // JPEG verisini düşük kalitede sıkıştır
        let reducedQuality: CGFloat = 0.2 // %80 düşük kalite
        guard let reducedJpegData = NSBitmapImageRep(data: jpegData)?.representation(using: .jpeg, properties: [.compressionFactor: reducedQuality]) else {
            print("Failed to reduce photo quality.")
            return
        }
        
        // Base64 string temsilini oluştur
        let photoString = reducedJpegData.base64EncodedString(options: .lineLength64Characters)
 
        // Fotoğrafın string temsilini kullan
        print("Photo string: \(photoString)")
        
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
        mqtt.willMessage = CocoaMQTTMessage(topic: "MacAgent", string: "\(photoString)")
        mqtt.keepAlive = 60
        mqtt.connect()
    }

}


  
