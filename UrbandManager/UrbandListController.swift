//
//  ViewController.swift
//  UrbandManage
//
//  Created by specktro on 11/13/16.
//  Copyright © 2016 specktro. All rights reserved.
//

import UIKit

class UrbandListController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "urbandCellIdentifier")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "urbandCellIdentifier", for: indexPath)
        cell.textLabel?.text = "urband \(indexPath.row + 1)"
        return cell
    }
}

