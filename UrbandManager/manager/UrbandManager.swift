//
//  UrbandManager.swift
//  Urband
//
//  Created by specktro on 11/12/16.
//  Copyright © 2016 DEX. All rights reserved.
//

import Foundation
import CoreBluetooth
import Alamofire

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
    
    public func notifyFA09(urband: CBPeripheral) {
        let fa09 = urband.services![1].characteristics![8]
//        let fa01 = urband.services![1].characteristics![0]
        urband.setNotifyValue(true, for: fa09)
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
    
    private func convert(_ param2: UInt8, _ param1: UInt8) -> Int {
        let signMask: UInt16 = 0b1000000000000000
        let xorMask: UInt16 = 0b1111111111111111
        
        var number: Int
        let high = UInt16(exactly: param2)! << 8
        let low = UInt16(exactly: param1)!
        let number1 = high | low
        let mask = number1 & signMask // validación de positivo o negativo
        
        if mask == signMask { // negativo
            let result = (number1 ^ xorMask) + UInt16(1)
            number = -1 * Int(exactly: result)!
        }
        else {
            number = Int(exactly: number1)!
        }
        
        return number
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        
        if let data = characteristic.value {
            let array = data.withUnsafeBytes {
                Array(UnsafeBufferPointer<UInt8>(start: $0, count: data.count / MemoryLayout<UInt8>.size))
            }
            
            if array.last == 2 { // Lectura del eje x del giroscopio
                let xArray = Array<UInt8>(array[44..<88])
                let xValues = [convert(xArray[0], xArray[1]),
                               convert(xArray[2], xArray[3]),
                               convert(xArray[4], xArray[5]),
                               convert(xArray[6], xArray[7]),
                               convert(xArray[8], xArray[9]),
                               convert(xArray[10], xArray[11]),
                               convert(xArray[12], xArray[13]),
                               convert(xArray[14], xArray[15]),
                               convert(xArray[16], xArray[17]),
                               convert(xArray[18], xArray[19]),
                               convert(xArray[20], xArray[21]),
                               convert(xArray[22], xArray[23]),
                               convert(xArray[24], xArray[25]),
                               convert(xArray[26], xArray[27]),
                               convert(xArray[28], xArray[29]),
                               convert(xArray[30], xArray[31]),
                               convert(xArray[32], xArray[33]),
                               convert(xArray[34], xArray[35]),
                               convert(xArray[36], xArray[37]),
                               convert(xArray[38], xArray[39]),
                               convert(xArray[40], xArray[41]),
                               convert(xArray[42], xArray[43])]
                var average = xValues.reduce(0) {
                    return $0 + $1 / array.count
                }
                
                let direction = average >= 0 ? 90 : 270
                if average < 0 {
                    average *= -1
                }
                average = average * 25 / 100
                
                print("average \(average) - direction \(direction)")
                
                let _ = Alamofire.request("http://50.50.50.49:8000/bb8/v1/run/?m=\(average)&d=\(direction)")
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


