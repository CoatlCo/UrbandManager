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
        UrbandManager.sharedInstance.managerDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let connectedUrband = UrbandManager.sharedInstance.connectedUrband {
            let alert = UIAlertController(title: "UrbandManager",
                                          message: "Ya se encuentra conectado a la Urband \(connectedUrband.identifier.uuidString)",
                                          preferredStyle: .alert)
            let connect = UIAlertAction(title: "Conectar", style: .cancel, handler: { _ in
                UrbandManager.sharedInstance.connect(connectedUrband)
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
        UrbandManager.sharedInstance.connect(urbands[indexPath.row])
    }
}

extension UrbandListController: UrbandManagerDelegate {
    func manager(state s: UMCentralState) {
        switch s {
        case .ready:
            UrbandManager.sharedInstance.urbandDelegate = self
            UrbandManager.sharedInstance.discover()
        default:
            let alert = UIAlertController(title: "Coatl Co.", message: "Problema con el bluetooth, posiblemente esté apagado", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(ok)
            present(alert, animated: true, completion: nil)
        }
    }
}

extension UrbandListController: UrbandDelegate {
    func newUrband(_ urband: CBPeripheral) {
        urbands.insert(urband, at: 0)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    
    func urbandReady(_ urband: CBPeripheral) {
        UrbandManager.sharedInstance.readFA01(urband) { result in
            switch result {
            case .success:
                debugPrint("The urband is working")
                let binaryToken: [UInt8] = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
                UrbandManager.sharedInstance.login(urband: urband, withToken: binaryToken)
                
                delay(seconds: 3.0) {
                    UrbandManager.sharedInstance.activateGestures(urband)
                    
                    delay(seconds: 2.0) {
                        UrbandManager.sharedInstance.confirmGesture(urband) { res in
                            switch res {
                            case .success:
                                debugPrint("Confirm gesture was detected")
                            case .failure:
                                debugPrint("Error while detecting gesture")
                            }
                        }
                    }
                }
            case .failure:
                debugPrint("The urband is not working correctly")
            }
        }
    }
}
