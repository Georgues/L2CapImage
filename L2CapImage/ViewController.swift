//
//  ViewController.swift
//  L2CapImage
//
//  Created by George Gostev on 08/04/2020.
//  Copyright © 2020 George Gostev. All rights reserved.
//

import UIKit
import ExternalAccessory
import CoreBluetooth
import L2Cap


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    // Peripheral variables
    private var peripheral: L2CapPeripheral!
    private var connection: L2CapConnection?
    //Central variables
    private var connectedPeripheral: CBPeripheral!
    private var getConnection:L2CapConnection!
    private var l2capCentral: L2CapCentral!
    private var characteristic: CBCharacteristic?
    
    private var queueQueue = DispatchQueue(label: "queue queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    private var outputData = Data()
    
    var imageParts: String = ""
    
    override func viewDidLoad() {
        
        
        super.viewDidLoad()
        
        TapObserver()
        
        // MARK: - Central Configurating
        self.l2capCentral = L2CapCentral()
        self.l2capCentral.discoveredPeripheralCallback = { peripheral in
            print("Discovered peripheral \(peripheral)")
            self.connectedPeripheral = peripheral
            self.l2capCentral.connect(peripheral: peripheral) { connection in
                self.getConnection = connection
                self.getConnection?.receiveCallback = { (connection,data) in
                    print("Received data")
                    self.processReceived(data: data)
                }
            }
        }
        // MARK: - Peripheral configurating
        self.peripheral = L2CapPeripheral(connectionHandler: { (connection) in
            self.connection = connection
            self.connection?.receiveCallback = { (connection, data) in
//                DispatchQueue.main.async {
//                    if let image = self.convertBase64ToImage(String(data: data, encoding: .utf8) ?? ""){
//                        self.imageView.image = image
//                    }
//                }
            }
        })
        
        ConfigureDevices()
        

    }
    
    func ConfigureDevices(){
        peripheral.publish = true
        l2capCentral.scan = true
    }
    
    func TapObserver(){
        let photoTap = UITapGestureRecognizer(target: self, action: #selector(TapOnPhoto))
        self.imageView.isUserInteractionEnabled = true
        self.imageView.addGestureRecognizer(photoTap)
    }
    
    @objc func TapOnPhoto(touch: UITapGestureRecognizer){
        print ("Tapped")
        let ac = UIAlertController(title: "Добавить новое фото", message: nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "Сделать новое фото", style: .default, handler: {(action) in
            self.chooseImagePickerAction(source: .camera)
        })
        let galeryAction = UIAlertAction(title: "Добавить фото из галереи", style: .default, handler: {(action) in
            self.chooseImagePickerAction(source: .photoLibrary)
        })
        let cancel = UIAlertAction(title: "Назад", style: .cancel, handler: {(action) in})
        ac.addAction(cameraAction)
        ac.addAction(galeryAction)
        ac.addAction(cancel)
        
        self.present(ac, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let profileImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {return}
        imageView.image = profileImage
        if self.getConnection != nil{
            startSending(image: profileImage)
            print ("Started sending")
        }
        dismiss(animated: true, completion: nil)
    }
    
    func chooseImagePickerAction (source: UIImagePickerController.SourceType){
        
        if UIImagePickerController.isSourceTypeAvailable(source){
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = source
            self.present(imagePicker, animated: true, completion: nil)
        }
        
    }
    
    func processReceived(data: Data) {
        print("processReceived with size = \(data.count)")
        if let string = String.init(data: data, encoding: .utf8) {
            self.imageParts.append(string)
            print(string)
            if imageParts.contains("FUNCINGEND") {
                print("END")
                let withoutFuncking = imageParts.replacingOccurrences(of: "FUNCINGEND", with: "")
                let withOpenBracket = "[" + withoutFuncking
                let withCommas = withOpenBracket.replacingOccurrences(of: "}{", with: "},{")
                let closeBracket = withCommas + "]"
                print(closeBracket)
                if let items = try? JSONSerialization.jsonObject(with: closeBracket.data(using: .utf8)!, options: .allowFragments) as? [[String: Any]] {
                    let sorted = items.sorted { ($0["packetNumber"] as! Int) < ($1["packetNumber"] as! Int) }
                    let reduced = sorted.map { $0["data"] as! String }.reduce("") { $0 + $1 }
                    let data =  Data(base64Encoded: items.first!["data"] as! String, options: .ignoreUnknownCharacters)!
                    self.imageView.image = UIImage(data: data)
                    }
                }
            
        }
    }
    
    func startSending(image: UIImage) {
        guard let base64ImageString = convertImageToBase64(image) else { return }
        
        for packet in createPackets(of: base64ImageString) {
            connection?.send(data: packet)
        }
    }
    
    func createChunk(with utf8: String.UTF8View, uuid: String, isLastPart: Bool, packetNumber: Int) -> Data? {
        
        let json = ["id": uuid, "isLastPart": isLastPart, "packetNumber": packetNumber, "data": String(utf8) ] as [String : Any]
        guard var data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return nil }
        
        if isLastPart {
            let fuck = "FUNCINGEND".data(using: .utf8)
            data.append(fuck!)
        }
        
        return data
    }
    
    func createPackets(of string: String) -> [Data] {
        
        var offset = 0
        let stringLenght = string.utf8.count
        let imageChunkSize = 875
        let id = UUID().uuidString
        
        var currentChunkNumber = 0
        
        var chunks: [Data] = []
        
        let utf8String = string.utf8
        offset += utf8String.count
        let isLastPart = true
        
        guard let chunk = createChunk(with: utf8String, uuid: id, isLastPart: isLastPart, packetNumber: currentChunkNumber) else {
            return []
            print("cant create chunk")
        }
        currentChunkNumber += 1
        chunks.append(chunk)
        
        return chunks
    }
    
    func convertImageToBase64(_ image: UIImage) -> String? {
           let imageData = image.jpegData(compressionQuality: 0.4)!
           let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
           return strBase64
    }
    
    func convertBase64ToImage(_ str: String) -> UIImage? {
        guard let dataDecoded : Data = Data(base64Encoded: str, options: .ignoreUnknownCharacters) else {return nil}
            let decodedimage = UIImage(data: dataDecoded)
            return decodedimage
    }
}

