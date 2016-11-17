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
struct UMConstants {
    static let DeviceInfoIdentifier = "180A"
    static let BaterryServiceIdentifier = "180F"
    static let UrbandServiceIdentifier = "FA00"
    static let HapticsServiceIdentifier = "FB00"
    static let SecurityServiceIdentifier = "FC00"
}

enum UMCentralState {
    case ready
    case problem(Error)
}

enum UMCentralError: Error {
    case poweredOff
    case unknown
    case resetting
    case unsupported
    case unauthorized
}

// MARK: - UrbandManagerDelegate
protocol UrbandManagerDelegate {
    func managerState(_ state: UMCentralState)
    func newUrband(_ urband: CBPeripheral)
}

// MARK: - UrbandManager Class
class UrbandManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
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
    
    // MARK: - External methods
    func discover() {
        let services = [CBUUID(string: UMConstants.DeviceInfoIdentifier),
                        CBUUID(string: UMConstants.BaterryServiceIdentifier),
                        CBUUID(string: UMConstants.UrbandServiceIdentifier),
                        CBUUID(string: UMConstants.HapticsServiceIdentifier),
                        CBUUID(string: UMConstants.SecurityServiceIdentifier)]
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    func connect(_ urband: CBPeripheral) {
        centralManager.connect(urband, options: nil)
    }
    
    // MARK: - CBCentralManagerDelegate methods
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var state: UMCentralState
        
        switch central.state {
        case .poweredOff:
            state = UMCentralState.problem(UMCentralError.poweredOff)
        case .poweredOn:
            state = UMCentralState.ready
        case .unknown:
            state = UMCentralState.problem(UMCentralError.unknown)
        case .resetting:
            state = UMCentralState.problem(UMCentralError.resetting)
        case .unsupported:
            state = UMCentralState.problem(UMCentralError.unsupported)
        case .unauthorized:
            state = UMCentralState.problem(UMCentralError.unauthorized)
        }
        
        delegate?.managerState(state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let _ = advertisementData[CBAdvertisementDataLocalNameKey] {
            debugPrint(peripheral.identifier.uuidString)
            delegate?.newUrband(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    // MARK: - CBPeripheralDelegate methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let bServices = peripheral.services?.filter {
            return $0.uuid.uuidString == UMConstants.BaterryServiceIdentifier
        }
        
        if let bService = bServices?.last {
            peripheral.discoverCharacteristics(nil, for: bService) // We get battery service characteristics
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if service.uuid.uuidString == UMConstants.BaterryServiceIdentifier {
            for c in service.characteristics! {
                peripheral.setNotifyValue(true, for: c)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.service.uuid.uuidString == UMConstants.BaterryServiceIdentifier {
            if let bData = characteristic.value {
                let bValue = bData.withUnsafeBytes({ (ptr: UnsafePointer<Int>) -> Int in
                    return ptr.pointee
                })
                
                debugPrint(bValue)
            }
        }
    }
}
