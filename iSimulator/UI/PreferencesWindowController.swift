//
//  PreferencesWindowController.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/11/16.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    static var firstTabSelectIdentifier = "General"
    @IBOutlet weak var toolBar: NSToolbar!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        var frame = self.window!.frame
        frame.origin.y = 600
        self.window?.setFrame(frame, display: true, animate: false)
        let identifier = NSToolbarItem.Identifier(rawValue: PreferencesWindowController.firstTabSelectIdentifier)
        toolBar.selectedItemIdentifier = identifier
        self.tabViewSelect(withIdentifier: identifier)
    }
    
    @IBAction func toolBarAction(_ sender: NSToolbarItem) {
        self.tabViewSelect(withIdentifier: sender.itemIdentifier)
    }
    
    func tabViewSelect(withIdentifier identifier: Any) {
        let vc = self.contentViewController as! PreferencesViewController
        vc.tabView.selectTabViewItem(withIdentifier: identifier)
    }
    
}
