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

/// Defines the urband services identifiers
struct UMServices {
    static let DeviceInfoIdentifier = "180A"
    static let BaterryServiceIdentifier = "180F"
    static let UrbandServiceIdentifier = "FA00"
    static let HapticsServiceIdentifier = "FB00"
    static let SecurityServiceIdentifier = "FC00"
}

/// Defines the urband characteristics values
struct UMCharacteristics {
    static let UrbandReady: UInt8 = 0x11
    static let DoubleTapGesture: UInt8 = 0x14
    static let ArmTwistGesture: UInt8 = 0x15
    static let ConfirmGesture: UInt8 = 0x16
}

/**
 Urband characteristic state used when it has not discovered yet anything from `CBPeripheral`
 
 - none: There is not setted characteristic
 - battery: Request battery characteristic `2A19`
 - ready: Request urband ready state, a `11` hex value from `FA01` characteristic
 - gesture: Request a gesture characteristic
 - compoundGesture: Characteristic state used when a compound gesture was detected
 */
enum CharState {
    case none
    case battery
    case ready
    case gesture
    case compoundGesture
}

/**
 Used to forward `CBCentralManagerDelegate` methods
 
 - ready: There are not problems with `CBCentralManagerDelegate`
 - problem: Forward specific `CBCentralManagerDelegate` error
 */
public enum UMCentralState {
    case ready
    case problem(Error)
}

/**
 Represents `CBCentralManagerDelegate` error types
 
 - poweredOff: The bluetooth device is turned off
 - unknown: There was an unknown error with bluetooth device
 - resetting: There was a resetting error in bluetooth device
 - unsupported: The bluetooth device is unsupported
 - unauthorized: The user unauthorized the bluetooth usage
 */
public enum UMCentralError: Error {
    case poweredOff
    case unknown
    case resetting
    case unsupported
    case unauthorized
}

/**
 Used to notice urband status
 
 - success: The urband is ready to use it
 - failure: The urband had a problem
 */
public enum UMDeviceStatus {
    case success
    case failure
}

/**
 Represents the closure results for urband callbacks
 
 - confirm: The double wrist twist gesture with `0x16` value
 - wrist: The double arm twist gesture with `0x15` value
 - doubleTap: The double tap gesture with `0x14` value
 */
public enum UMGestureResponse {
    case confirm
    case wrist
    case doubleTap(UInt8)
    case failure
}

// MARK: - UrbandManagerDelegate protocol
/// Protocol to forward `CBCentralManagerDelegate` methods
public protocol UrbandManagerDelegate: class {
    /**
     Returns the `CBCentralManagerDelegate` state
     
     - Parameter s: The final `CBCentralManagerDelegate` state represented by `UMCentralState`
     */
    func manager(state s: UMCentralState)
    
    /**
     Returns new urband found by `CBCentralManagerDelegate`
     
     - Parameter urband: The urband found
     */
    func newUrband(_ urband: CBPeripheral)
}

// MARK: - UrbandDelegate protocol
/// Notice the urband's state
public protocol UrbandDelegate: class {
    /**
     Returns the new urband ready to use
     
     - Parameter urband: The actual urband
     */
    func urbandReady(_ urband: CBPeripheral)
    
    /**
     Returns the new urband disconnected
     
     - Parameter u: The actual urband
     */
    func disconnected(urband u: CBPeripheral)
}

// MARK: - UrbandManager Class
/// UrbandManager singleton class
public class UrbandManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager
    private var services: [String]
    private var gestureClosure: ((UMGestureResponse) -> ())?
    private var readyClosure: ((UMDeviceStatus) -> ())?
    private var batteryClosure: ((UInt8) -> ())?
    private var charState: CharState = .none
    private(set) public var connectedUrband: CBPeripheral?
    
    public weak var managerDelegate: UrbandManagerDelegate?
    public weak var urbandDelegate: UrbandDelegate?
    
    // MARK: Singleton stuff
    static public let shared = UrbandManager()
    
    /**
     Initialize the singleton variables
     */
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
    
    /**
     Verifies if there is a last connected `CBPeripheral` after the singleton conforms `CBCentralManagerDelegate` methods
     */
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
    
    /**
     Creates an array with service values to discover them
     */
    private func fillServices() {
        services = [UMServices.DeviceInfoIdentifier,
                    UMServices.BaterryServiceIdentifier,
                    UMServices.UrbandServiceIdentifier,
                    UMServices.HapticsServiceIdentifier,
                    UMServices.SecurityServiceIdentifier]
    }
    
    /**
     Notifies value from any characteristic in `CBPeripheral`
     
     - Parameter p: The actual urband
     - Parameter optC: The characteristic to notify
     - Parameter state: The `CharState` to save if there are not services
     */
    private func notifyChange(peripheral p: CBPeripheral, forCharacteristic optC: CBCharacteristic?, state: CharState) {
        guard let characteristic = optC else {
            charState = state
            fillServices()
            p.discoverServices(nil)
            return
        }
        
        p.setNotifyValue(true, for: characteristic)
    }
    
    /**
     Reads a value from any characteristic in `CBPeripheral`
     
     - Parameter optC: The characteristic to notify
     - Parameter p: The actual urband
     - Parameter state: The `CharState` to save if there are not services
     */
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
    /**
     Starts to discover `CBPeripheral`s with the services given
     */
    public func discover() {
        let services = [CBUUID(string: UMServices.DeviceInfoIdentifier),
                        CBUUID(string: UMServices.BaterryServiceIdentifier),
                        CBUUID(string: UMServices.UrbandServiceIdentifier),
                        CBUUID(string: UMServices.HapticsServiceIdentifier),
                        CBUUID(string: UMServices.SecurityServiceIdentifier)]
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    /// Cancels scanning for peripherals `CBCentralManager`
    public func cancelDiscovering() {
        centralManager.stopScan()
    }
    
    /**
     Connects an urband with the `CBCentralManager`
     
     - Parameter urband: The urband to connect
     */
    public func connect(_ urband: CBPeripheral) {
        centralManager.connect(urband, options: nil)
    }
    
    /**
     Disconnects an urband from the `CBCentralManager`
     
     - Parameter urband: The urband to disconnect
     */
    public func disconnect(_ urband: CBPeripheral) {
        centralManager.cancelPeripheralConnection(urband)
    }
    
    /**
     Reads the urband battery characteristic
     
     - Parameter u: `CBPeripheral` to read its battery
     - Parameter response: Closure callback where the battery value is returned
     */
    public func readBattery(forUrband u: CBPeripheral, response: @escaping (UInt8) -> ()) {
        batteryClosure = response
        let c2A19 = u.services?[4].characteristics?[0]
        notifyChange(peripheral: u, forCharacteristic: c2A19, state: .battery)
    }
    
    /**
     Cancel the battery characteristic notification
     
     - Parameter u: `CBPeripheral` to cancel the battery reading
     */
    public func cancelBattery(forUrband u: CBPeripheral) {
        if let c2A19 = u.services?[4].characteristics?[0] {
            u.setNotifyValue(false, for: c2A19)
        }
        else {
            debugPrint("There are not discover characteristics in urband \(u.identifier.uuidString)")
        }
    }
    
    /**
     Determines if the urband is ready
     
     - Parameter urband: `CBPeripheral` to read its status
     - Parameter response: Closure to callback the urband status
     */
    public func readFA01(_ urband: CBPeripheral, response: @escaping (UMDeviceStatus) -> ()) {
        // FIXME: Create a readFA01 gesture just for checking the correct function of the urband
        readyClosure = response
        let cfa01 = urband.services?[1].characteristics?[0]
        read(characteristic: cfa01, fromPeripheral: urband, state: .ready)
    }
    
    /**
     Sends a token for login with the urband, actually this value is an UInt8 array with two zero bytes
     
     - Parameter u: `CBPeripheral` to login with it
     - Parameter token: UInt8 byte array with token value
     */
    public func login(urband u: CBPeripheral, withToken token: [UInt8]) {
        let fc02 = u.services![3].characteristics![1]
        u.writeValue(Data(bytes: token), for: fc02, type: .withResponse)
    }
    
    /**
     Activates the urband gestures, they have to be activated
     
     - Parameter urband: The urband to activate its gestures
     */
    public func activateGestures(_ urband: CBPeripheral) {
        if let cfa01 = urband.services?[1].characteristics?[0] {
            urband.writeValue(Data(bytes: [0x00]), for: cfa01, type: .withResponse)
        }
        else {
            debugPrint("There are not discover characteristics in urband \(urband.identifier.uuidString)")
        }
    }
    
    /**
     Deactivates the urband gestures, they have to be deactivated after their use
     
     - Parameter urband: The urband to deactivate its gestures
     */
    public func deactivateGestures(_ urband: CBPeripheral) {
        if let cfa01 = urband.services?[1].characteristics?[0] {
            urband.writeValue(Data(bytes: [0x01]), for: cfa01, type: .withResponse)
        }
        else {
            debugPrint("There are not discover characteristics in urband \(urband.identifier.uuidString)")
        }
    }
    
    /**
     Notifies every gesture processed by an urband
     
     - Parameter urband: The urband to track its gestures
     - Parameter response: Closure used to send gestures result
     */
    public func notifyGestures(_ urband: CBPeripheral, response: @escaping (UMGestureResponse) -> ()) {
        gestureClosure = response
        let cfa01 = urband.services?[1].characteristics?[0]
        notifyChange(peripheral: urband, forCharacteristic: cfa01, state: .gesture)
    }
    
    /**
     Cancels the gesture closure callback
     
     - Parameter urband: The urband to cancel gestures callback
     */
    public func cancelGesturesNotification(urband: CBPeripheral) {
        if let c2A19 = urband.services?[1].characteristics?[0] {
            urband.setNotifyValue(false, for: c2A19)
            gestureClosure = nil
        }
        else {
            debugPrint("There are not discover characteristics in urband \(urband.identifier.uuidString)")
        }
    }
    
    /**
     Sends a haptic message to the urband
     
     - Parameter urband: The urband to activate heptics message
     - Parameter colorRep: An UInt8 array to represent the color in HEX form
     - Parameter times: The number of times that haptic event is going to repeat
     */
    public func activate(urband: CBPeripheral, withColor colorRep: [Int], repeat times: Int) {
        if colorRep.count != 3 {
            fatalError("The color can¡t have more thant three components")
        }
        
        if let cFB01 = urband.services?[2].characteristics?[0],
            let cFB02 = urband.services?[2].characteristics?[1] {
            let vibIntensity1: UInt8 = 0x32 // 50
            let vibIntensity2: UInt8 = 0x64 // 100
            let ledIntensity1: UInt8 = 0x32 // 50
            let ledIntensity2: UInt8 = 0x64 // 100
            let t1: UInt8 = 0x64
            let t2: UInt8 = 0x64
            let t3: UInt8 = 0x64
            let t4: UInt8 = 0x64
            let t5: UInt8 = 0x64
            
            let config: [UInt8] = [vibIntensity1, vibIntensity2, ledIntensity1, ledIntensity2, t1, t2, t3, t4, t5, UInt8(colorRep[0]), UInt8(colorRep[1]), UInt8(colorRep[2])]
            urband.writeValue(Data(bytes: config), for: cFB02, type: .withResponse)
            urband.writeValue(Data(bytes: [UInt8(times)]), for: cFB01, type: .withResponse)
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
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastConnectedUrband)
        UserDefaults.standard.synchronize()
        peripheral.delegate = self
        connectedUrband = peripheral
        
        if let _ = peripheral.services {
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
            
            switch value {
            case UMCharacteristics.UrbandReady:
                debugPrint("The urband is ready and without problems")
                readyClosure?(UMDeviceStatus.success)
                readyClosure = nil
            case UMCharacteristics.ConfirmGesture:
                debugPrint("The urband confirm gesture was detected")
                
                if charState == .compoundGesture {
                    charState = .none
                }
                
                gestureClosure?(UMGestureResponse.confirm)
            case UMCharacteristics.ArmTwistGesture:
                debugPrint("The urband double arm twist gesture was detected")
                gestureClosure?(UMGestureResponse.wrist)
            case UMCharacteristics.DoubleTapGesture:
                debugPrint("The double tap gesture was detected")
                charState = .compoundGesture
            default:
                if charState == .compoundGesture {
                    gestureClosure?(UMGestureResponse.doubleTap(value))
                }
            }
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


