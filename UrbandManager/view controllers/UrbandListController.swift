//
//  ViewController.swift
//  UrbandManage
//
//  Created by specktro on 11/13/16.
//  Copyright © 2016 specktro. All rights reserved.
//

import UIKit
import CoreBluetooth

class UrbandListController: UITableViewController {
    fileprivate var urbands: [CBPeripheral] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "urbandCellIdentifier")
        UrbandManager.shared.managerDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let connectedUrband = UrbandManager.shared.connectedUrband {
            let alert = UIAlertController(title: "UrbandManager",
                                          message: "Ya se encuentra conectado a la Urband \(connectedUrband.identifier.uuidString)",
                                          preferredStyle: .alert)
            let connect = UIAlertAction(title: "Conectar", style: .cancel, handler: { _ in
                UrbandManager.shared.connect(connectedUrband)
            })
            
            alert.addAction(connect)
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - UITableViewDataSource methods
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urbands.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "urbandCellIdentifier", for: indexPath)
        let u = urbands[indexPath.row]
        cell.textLabel?.text = u.identifier.uuidString
        return cell
    }
    
    // MARK: - UITableViewDelegate methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UrbandManager.shared.connect(urbands[indexPath.row])
    }
}

extension UrbandListController: UrbandManagerDelegate {
    func manager(state s: UMCentralState) {
        switch s {
        case .ready:
            UrbandManager.shared.urbandDelegate = self
            UrbandManager.shared.discover()
        default:
            let alert = UIAlertController(title: "Coatl Co.", message: "Problema con el bluetooth, posiblemente esté apagado", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(ok)
            present(alert, animated: true, completion: nil)
        }
    }
    
    func newUrband(_ urband: CBPeripheral) {
        urbands.insert(urband, at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
}

extension UrbandListController: UrbandDelegate {
    func urbandReady(_ urband: CBPeripheral) {
        UrbandManager.shared.readFA01(urband) { result in
            switch result {
            case .success:
                debugPrint("The urband is working")
                let binaryToken: [UInt8] = [0x00, 0x00]
                UrbandManager.shared.login(urband: urband, withToken: binaryToken)
                
                delay(seconds: 3.0) {
                    // MARK: - Haptics
                    // TODO: If you want to test haptics use this code
                    UrbandManager.shared.activate(urband: urband, withColor: [255, 127, 0], repeat: 10)
                    
                    // MARK: - Gestures
                    // TODO: If you want to test gestures use this code
//                    UrbandManager.shared.activateGestures(urband)
//
//                    delay(seconds: 2.0) {
//                        UrbandManager.shared.notifyGestures(urband, response: { res in
//                            switch res {
//                            case .confirm:
//                                debugPrint("Confirm gesture was detected")
//                            case .wrist:
//                                debugPrint("Wrist gesture was detected")
//                            case .doubleTap(let value):
//                                debugPrint("Value detected \(value)")
//                            case .failure:
//                                debugPrint("Error while detecting gesture")
//                            }
//                        })
//                    }
                }
            case .failure:
                debugPrint("The urband is not working correctly")
            }
        }
    }
    
    func disconnected(urband u: CBPeripheral) {
        let alert = UIAlertController(title: nil, message: "The urband \(u.identifier.uuidString) was disconnected successful", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
