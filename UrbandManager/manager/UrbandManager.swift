//
//  UrbandManager.swift
//  Urband
//
//  Created by specktro on 11/12/16.
//  Copyright © 2016 DEX. All rights reserved.
//

import Foundation
import CoreBluetooth

// MARK: - Constants
struct CBConstants {
    static let DeviceInfoIdentifier = "180A"
    static let BaterryServiceIdentifier = "180F"
    static let UrbandServiceIdentifier = "FA00"
    static let HapticsServiceIdentifier = "FB00"
    static let SecurityServiceIdentifier = "FC00"
}

// MARK: - UrbandManagerDelegate
protocol UrbandManagerDelegate {
    func newUrband(_ urband: CBPeripheral)
}

// MARK: - UrbandManager Class
class UrbandManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager
    var delegate: UrbandManagerDelegate?
    
    // MARK: Singleton stuff
    static let sharedInstance = UrbandManager()
    
    private override init() {
        centralManager = CBCentralManager()
        super.init()
        
        start()
    }
    
    private func start() {
        centralManager.delegate = self
    }
    
    // MARK: - CBCentralManagerDelegate methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("poweredOff")
        case .poweredOn:
            let services = [CBUUID(string: CBConstants.DeviceInfoIdentifier),
                            CBUUID(string: CBConstants.BaterryServiceIdentifier),
                            CBUUID(string: CBConstants.UrbandServiceIdentifier),
                            CBUUID(string: CBConstants.HapticsServiceIdentifier),
                            CBUUID(string: CBConstants.SecurityServiceIdentifier)]
            central.scanForPeripherals(withServices: services, options: nil)
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let _ = advertisementData[CBAdvertisementDataLocalNameKey] {
            debugPrint(peripheral.identifier.uuidString)
            delegate?.newUrband(peripheral)
        }
    }
}
