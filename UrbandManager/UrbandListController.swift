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
        UrbandManager.sharedInstance.delegate = self
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
    func managerState(_ state: UMCentralState) {
        switch state {
        case .ready:
            UrbandManager.sharedInstance.discover()
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
    
    func urbandReady(_ urband: CBPeripheral) {
        UrbandManager.sharedInstance.readFA01(urband: urband)
    }
}
