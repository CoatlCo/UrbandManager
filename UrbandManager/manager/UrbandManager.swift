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
struct UMServices {
    static let DeviceInfoIdentifier = "180A"
    static let BaterryServiceIdentifier = "180F"
    static let UrbandServiceIdentifier = "FA00"
    static let HapticsServiceIdentifier = "FB00"
    static let SecurityServiceIdentifier = "FC00"
}

struct UMCharacteristics {
    static let UrbandReady: UInt8 = 0x11
    static let CompoundGesture: UInt8 = 0x14
    static let DoubleTapGesture: UInt8 = 0x15
    static let ConfirmGesture: UInt8 = 0x16
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

public enum UMGestureResponse {
    case success
    case failure
}

// MARK: - UrbandManagerDelegate protocol
public protocol UrbandManagerDelegate: class {
    func managerState(_ state: UMCentralState)
    func newUrband(_ urband: CBPeripheral)
    func urbandReady(_ urband: CBPeripheral)
}

// MARK: - UrbandManager Class
public class UrbandManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager
    private var services: [String]
    private var confirmClosure: ((UMGestureResponse) -> Void)?
    public weak var delegate: UrbandManagerDelegate?
    
    // MARK: Singleton stuff
    static public let sharedInstance = UrbandManager()
    
    private override init() {
        centralManager = CBCentralManager()
        services = [UMServices.DeviceInfoIdentifier,
                    UMServices.BaterryServiceIdentifier,
                    UMServices.UrbandServiceIdentifier,
                    UMServices.HapticsServiceIdentifier,
                    UMServices.SecurityServiceIdentifier]
        super.init()
        
        start()
    }
    
    private func start() {
        centralManager.delegate = self
    }
    
    // MARK: - External methods
    public func discover() {
        let services = [CBUUID(string: UMServices.DeviceInfoIdentifier),
                        CBUUID(string: UMServices.BaterryServiceIdentifier),
                        CBUUID(string: UMServices.UrbandServiceIdentifier),
                        CBUUID(string: UMServices.HapticsServiceIdentifier),
                        CBUUID(string: UMServices.SecurityServiceIdentifier)]
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    public func connect(_ urband: CBPeripheral) {
        centralManager.connect(urband, options: nil)
    }
    
    public func readFA01(_ urband: CBPeripheral, response: @escaping (UMGestureResponse) -> Void) {
        let fa01 = urband.services![1].characteristics![0]
        urband.readValue(for: fa01)
        confirmClosure = response
    }
    
    public func login(urband u: CBPeripheral, withToken token: [UInt8]) {
        let fc02 = u.services![3].characteristics![1]
        u.writeValue(Data(bytes: token), for: fc02, type: .withResponse)
    }
    
    public func activateGestures(_ urband: CBPeripheral) {
        let fa01 = urband.services![1].characteristics![0]
        urband.writeValue(Data(bytes: [0x00]), for: fa01, type: .withResponse)
    }
    
    public func confirmGesture(_ urband: CBPeripheral, response: @escaping (UMGestureResponse) -> Void) {
        let fa01 = urband.services![1].characteristics![0]
        urband.setNotifyValue(true, for: fa01)
        confirmClosure = response
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
        guard let data = characteristic.value else {
            debugPrint("There is not a value in the characteristic")
            return
        }
        
        let dataArray = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<UInt8>(start: $0, count: data.count / MemoryLayout<UInt8>.size))
        }
        
        if let closure = confirmClosure {
            guard let value = dataArray.first else {
                closure(.failure)
                confirmClosure = nil
                return
            }
            
            if characteristic.uuid.uuidString == "FA01" {
                switch value {
                case UMCharacteristics.UrbandReady:
                    debugPrint("The urband is ready and without problems")
                    closure(UMGestureResponse.success)
                    confirmClosure = nil
                case UMCharacteristics.ConfirmGesture:
                    debugPrint("The urband confirm gesture was detected")
                    closure(UMGestureResponse.success)
                    confirmClosure = nil
                default:
                    debugPrint("Unrecognized value in characteristic \(characteristic.uuid.uuidString)")
                }
            }
        }
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


