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
                }
            }
        }
        // MARK: - Peripheral configurating
        self.peripheral = L2CapPeripheral(connectionHandler: { (connection) in
            self.connection = connection
            self.connection?.receiveCallback = { (connection, data) in
                DispatchQueue.main.async {
                    if let image = self.convertBase64ToImage(String(data: data, encoding: .utf8) ?? ""){
                        self.imageView.image = image
                    }
                }
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
        guard let connection = self.getConnection else {
            return
        }
        
        if let image = self.imageView.image, let data = image.jpegData(compressionQuality: 0.1){
//            let base64Str = data.base64EncodedString()
            let base64Str = convertImageToBase64(image)
            let base64Data = base64Str.data(using: .utf8)!
            connection.send(data: base64Data)
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
    
    func convertImageToBase64(_ image: UIImage) -> String {
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

