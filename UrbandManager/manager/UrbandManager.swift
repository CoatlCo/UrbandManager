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
public struct UMConstants {
    static let DeviceInfoIdentifier = "180A"
    static let BaterryServiceIdentifier = "180F"
    static let UrbandServiceIdentifier = "FA00"
    static let HapticsServiceIdentifier = "FB00"
    static let SecurityServiceIdentifier = "FC00"
}

public enum UMCentralState {
    case ready
    case problem(Error)
}

public enum UMCentralError: Error {
    case poweredOff
    case unknown
    case resetting
    case unsupported
    case unauthorized
}

// MARK: - UrbandManagerDelegate protocol
public protocol UrbandManagerDelegate {
    func managerState(_ state: UMCentralState)
    func newUrband(_ urband: CBPeripheral)
    func urbandReady(_ urband: CBPeripheral)
}

// MARK: - UrbandManager Class
public class UrbandManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager
    private var services: [String]
    public var delegate: UrbandManagerDelegate?
    
    // MARK: Singleton stuff
    static public let sharedInstance = UrbandManager()
    
    private override init() {
        centralManager = CBCentralManager()
        services = [UMConstants.DeviceInfoIdentifier,
                    UMConstants.BaterryServiceIdentifier,
                    UMConstants.UrbandServiceIdentifier,
                    UMConstants.HapticsServiceIdentifier,
                    UMConstants.SecurityServiceIdentifier]
        super.init()
        
        start()
    }
    
    private func start() {
        centralManager.delegate = self
    }
    
    // MARK: - External methods
    public func discover() {
        let services = [CBUUID(string: UMConstants.DeviceInfoIdentifier),
                        CBUUID(string: UMConstants.BaterryServiceIdentifier),
                        CBUUID(string: UMConstants.UrbandServiceIdentifier),
                        CBUUID(string: UMConstants.HapticsServiceIdentifier),
                        CBUUID(string: UMConstants.SecurityServiceIdentifier)]
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    public func connect(_ urband: CBPeripheral) {
        centralManager.connect(urband, options: nil)
    }
    
    public func readFA01(urband: CBPeripheral) {
        let fa01 = urband.services![1].characteristics![0]
        urband.readValue(for: fa01)
    }
    
    public func writeFC02(urband: CBPeripheral) {
        let fc02 = urband.services![3].characteristics![1]
        urband.writeValue(Data(bytes: [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]), for: fc02, type: .withResponse)
    }
    
    // MARK: - CBCentralManagerDelegate methods
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let _ = advertisementData[CBAdvertisementDataLocalNameKey] {
            debugPrint(peripheral.identifier.uuidString)
            delegate?.newUrband(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        
        if let _ = peripheral.services {
            delegate?.urbandReady(peripheral)
        }
        else {
            peripheral.discoverServices(nil)
        }
    }
    
    // MARK: - CBPeripheralDelegate methods
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services! {
            peripheral.characteristicsForService(s.uuid.uuidString)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let index = services.index(of: service.uuid.uuidString)
        services.remove(at: index!)
        
        if services.count == 0 {
            delegate?.urbandReady(peripheral)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint(characteristic.value?.hexEncodedString() ?? "I can't read characteristic")
    }
}

// MARK: - CBPeripheral methods
extension CBPeripheral {
    fileprivate func characteristicsForService(_ service: String) {
        let bServices = self.services?.filter { $0.uuid.uuidString == service }
        
        if let bService = bServices?.last {
            self.discoverCharacteristics(nil, for: bService)
        }
    }
}

