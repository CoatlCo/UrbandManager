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
let lastConnectedUrband = "last_connected_uuid"

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

enum CharState {
    case none
    case battery
    case ready
    case gesture
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

public enum UMDeviceStatus {
    case success
    case failure
}

public enum UMGestureResponse {
    case confirm
    case failure
}

// MARK: - UrbandManagerDelegate protocol
public protocol UrbandManagerDelegate: class {
    func manager(state s: UMCentralState)
    func newUrband(_ urband: CBPeripheral)
}

// MARK: - UrbandDelegate protocol
public protocol UrbandDelegate: class {
    func urbandReady(_ urband: CBPeripheral)
    func disconnected(urband u: CBPeripheral)
}

// MARK: - UrbandManager Class
public class UrbandManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager
    private var services: [String]
    private var gestureClosure: ((UMGestureResponse) -> Void)?
    private var readyClosure: ((UMDeviceStatus) -> Void)?
    private var batteryClosure: ((UInt8) -> Void)?
    private var charState: CharState = .none
    private(set) public var connectedUrband: CBPeripheral?
    
    public weak var managerDelegate: UrbandManagerDelegate?
    public weak var urbandDelegate: UrbandDelegate?
    
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
        // We get the last connected urband device in the connectedUrband variable
        if let uuidString = UserDefaults.standard.string(forKey: lastConnectedUrband) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [UUID(uuidString: uuidString)!])
            
            if let peripheral = peripherals.last {
                connectedUrband = peripheral
            }
        }
        
        centralManager.delegate = self
    }
    
    private func fillServices() {
        services = [UMServices.DeviceInfoIdentifier,
                    UMServices.BaterryServiceIdentifier,
                    UMServices.UrbandServiceIdentifier,
                    UMServices.HapticsServiceIdentifier,
                    UMServices.SecurityServiceIdentifier]
    }
    
    private func notifyChange(peripheral p: CBPeripheral, forCharacteristic optC: CBCharacteristic?, state: CharState) {
        guard let characteristic = optC else {
            charState = state
            fillServices()
            p.discoverServices(nil)
            return
        }
        
        p.setNotifyValue(true, for: characteristic)
    }
    
    private func read(characteristic optC: CBCharacteristic?, fromPeripheral p: CBPeripheral, state: CharState) {
        guard let characteristic = optC else {
            charState = state
            fillServices()
            p.discoverServices(nil)
            return
        }
        
        p.readValue(for: characteristic)
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
        UserDefaults.standard.set(urband.identifier.uuidString, forKey: lastConnectedUrband)
        UserDefaults.standard.synchronize()
        
        centralManager.connect(urband, options: nil)
    }
    
    public func disconnect(_ urband: CBPeripheral) {
        centralManager.cancelPeripheralConnection(urband)
    }
    
    public func readBattery(forUrband u: CBPeripheral, response: @escaping (UInt8) -> Void) {
        batteryClosure = response
        let c2A19 = u.services?[4].characteristics?[0]
        notifyChange(peripheral: u, forCharacteristic: c2A19, state: .battery)
    }
    
    public func cancelBattery(forUrband u: CBPeripheral) {
        if let c2A19 = u.services?[4].characteristics?[0] {
            u.setNotifyValue(false, for: c2A19)
        }
        else {
            debugPrint("There are not discover characteristics in urband \(u.identifier.uuidString)")
        }
    }
    
    public func readFA01(_ urband: CBPeripheral, response: @escaping (UMDeviceStatus) -> Void) {
        // FIXME: Create a readFA01 gesture just for checking the correct function of the urband
        readyClosure = response
        let cfa01 = urband.services?[1].characteristics?[0]
        read(characteristic: cfa01, fromPeripheral: urband, state: .ready)
    }
    
    public func login(urband u: CBPeripheral, withToken token: [UInt8]) {
        let fc02 = u.services![3].characteristics![1]
        u.writeValue(Data(bytes: token), for: fc02, type: .withResponse)
    }
    
    public func activateGestures(_ urband: CBPeripheral) {
        let fa01 = urband.services![1].characteristics![0]
        urband.writeValue(Data(bytes: [0x00]), for: fa01, type: .withResponse)
    }
    
    public func notifyGestures(_ urband: CBPeripheral, response : @escaping (UMGestureResponse) -> Void) {
        gestureClosure = response
        let cfa01 = urband.services?[1].characteristics?[0]
        notifyChange(peripheral: urband, forCharacteristic: cfa01, state: .gesture)
    }
    
    public func cancelGesturesNotification(urband: CBPeripheral) {
        if let c2A19 = urband.services?[1].characteristics?[0] {
            urband.setNotifyValue(false, for: c2A19)
            gestureClosure = nil
        }
        else {
            debugPrint("There are not discover characteristics in urband \(urband.identifier.uuidString)")
        }
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
        
        managerDelegate?.manager(state: state)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let _ = advertisementData[CBAdvertisementDataLocalNameKey] {
            debugPrint(peripheral.identifier.uuidString)
            managerDelegate?.newUrband(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        
        if let _ = peripheral.services {
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastConnectedUrband)
            
            connectedUrband = peripheral
            urbandDelegate?.urbandReady(peripheral)
        }
        else {
            peripheral.discoverServices(nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        UserDefaults.standard.removeObject(forKey: lastConnectedUrband)
        UserDefaults.standard.synchronize()
        connectedUrband = nil
        urbandDelegate?.disconnected(urband: peripheral)
    }
    
    // MARK: - CBPeripheralDelegate methods
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services! {
            peripheral.characteristicsForService(s.uuid.uuidString)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if charState != .none {
            switch charState {
            case .battery:
                readBattery(forUrband: peripheral, response: batteryClosure!)
            case .ready:
                debugPrint("Implementar un closure específico para checar el status de la urband")
                readFA01(peripheral, response: readyClosure!)
            case .gesture:
                notifyGestures(peripheral, response: gestureClosure!)
            default:
                debugPrint("There is no state")
            }
            
            charState = .none
        }
        else {
            if let index = services.index(of: service.uuid.uuidString) {
                services.remove(at: index)
            }
            
            if services.count == 0 {
                urbandDelegate?.urbandReady(peripheral)
            }
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
        
        switch characteristic.uuid.uuidString {
        case "2A19":
            if let bc = batteryClosure {
                debugPrint("Battery value \(dataArray.first!)")
                bc(dataArray.first!)
                return
            }
        case "FA01":
            guard let value = dataArray.first else {
                gestureClosure?(.failure)
                gestureClosure = nil
                return
            }
            
            debugPrint("Characteristic \(characteristic.uuid.uuidString) - value \(value)")

            switch value {
            case UMCharacteristics.UrbandReady:
                debugPrint("The urband is ready and without problems")
                readyClosure?(UMDeviceStatus.success)
                readyClosure = nil
            case UMCharacteristics.ConfirmGesture:
                debugPrint("The urband confirm gesture was detected")
                gestureClosure?(UMGestureResponse.confirm)
//                confirmClosure = nil
            default:
                debugPrint("Unrecognized value in characteristic \(characteristic.uuid.uuidString)")
            }
//            if let closure = confirmClosure {
//                
//            }
        default:
            debugPrint("The characteristic \(characteristic.uuid.uuidString) is not defined yet")
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


