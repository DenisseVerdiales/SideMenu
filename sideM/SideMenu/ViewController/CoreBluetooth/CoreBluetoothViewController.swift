//
//  CoreBluetoothViewController.swift
//  SideMenu
//
//  Created by Consultant on 2/2/23.
//

import UIKit
import CoreBluetooth

class CoreBluetoothViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
  
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth"
        view.backgroundColor = .systemGreen
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            print("Central state is .unknown")
        case .resetting:
            print("Central state is .resetting")
        case .unsupported:
            print("Central state is .unsupported")
        case .unauthorized:
            print("Central state is .unauthorized")
        case .poweredOff:
            print("Central state is .poweredOff")
        case .poweredOn:
            print("Central state is .poweredOn")
            //let audioSpeakerServiceCBUUID = CBUUID(string: "0x180D")
            //centralManager.scanForPeripherals(withServices: [audioSpeakerServiceCBUUID])
            centralManager?.scanForPeripherals(withServices: nil)
        @unknown default:
            print("default")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        //see the peripheral printed just once.
        print(peripheral)
        self.peripheral?.delegate = self
        self.peripheral = peripheral
        centralManager?.stopScan()
        guard let peripheral = self.peripheral else {return}
        centralManager?.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        self.peripheral?.discoverServices(nil)
       // self.peripheral?.discoverServices([audioSpeakerServiceCBUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
                //print(service.characteristics ?? "characteristics are nil")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
          guard let characteristics = service.characteristics else { return }

          for characteristic in characteristics {
            print(characteristic)
          }
    }
    
}
