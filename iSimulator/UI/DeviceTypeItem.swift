//
//  DeviceTypeItem.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/11/16.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Cocoa

class DeviceTypeCreateItem: NSMenuItem {
    init() {
        super.init(title: "Create New Simulator", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        TotalModel.default.runtimes.forEach { (r) in
            let item = RuntimeTypeCreateItem.init(r)
            menu.addItem(item)
        }
        self.submenu = menu
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class RuntimeTypeCreateItem: NSMenuItem {
    let runtime: Runtime
    init(_ runtime: Runtime) {
        self.runtime = runtime
        super.init(title: runtime.name, action: nil, keyEquivalent: "")
        self.submenu = createDeviceItem()
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func createDeviceItem() -> NSMenu {
        let menu = NSMenu()
        runtime.devicetypes.forEach {
            let item = NSMenuItem.init(title: $0.name, action: #selector(DeviceCreateAction.perform), keyEquivalent: "")
            let action = DeviceCreateAction.init(deviceType: $0, runtime: runtime)
            item.target = action
            item.representedObject = action
            menu.addItem(item)
        }
        return menu
    }
}

class DeviceCreateAction {
    let deviceType: DeviceType
    let runtime: Runtime
    var icon: NSImage?
    required init(deviceType: DeviceType, runtime: Runtime) {
        self.deviceType = deviceType
        self.runtime = runtime
    }
    
    @objc func perform() {
        let alert: NSAlert = NSAlert()
        alert.messageText = "Create a new simulator"
        let view = NSView.init(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
        let prefixWidth: CGFloat = 102
        let prefixNameField = NSTextField.init(frame: NSRect(x: 0, y: 0, width: prefixWidth, height: 22))
        prefixNameField.stringValue = "Simulator Name:"
        prefixNameField.drawsBackground = false
        prefixNameField.isBordered = false
        prefixNameField.isEditable = false
        view.addSubview(prefixNameField)
        let nameField = NSTextField.init(frame: NSRect(x: prefixWidth, y: 0, width: 180, height: 22))
        nameField.placeholderString = deviceType.name
        nameField.isEditable = true
        view.addSubview(nameField)
        alert.accessoryView = view
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        nameField.becomeFirstResponder()
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            var simName = self.deviceType.name
            if !nameField.stringValue.isEmpty {
                simName = nameField.stringValue
            }
            let result = shell("/usr/bin/xcrun", arguments: "simctl", "create", simName, deviceType.identifier, runtime.identifier)
            if result.outStr.isEmpty{
                createFail(error: result.err, name: simName)
            }else{
                createSuccess(udid: result.outStr, name: simName)
            }
        }
    }
    
    func createFail(error:String, name:String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = "Create \(name) failed!"
        var newError = error
        
        if let err = error.split(separator: ":").last {
            newError = "Error: \(err)"
        }
        alert.informativeText = newError
        alert.addButton(withTitle: "Done")
        alert.alertStyle = .critical
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    func createSuccess(udid: String, name:String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = "Create \(name) success!"
        alert.informativeText = "Boot this simulator?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        var udid = udid
        if udid.hasSuffix("\n") {
            udid.removeLast()
        }
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            let device = Device()
            device.udid = udid
            try? device.boot()
        }
    }
}

