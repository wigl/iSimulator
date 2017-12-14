//
//  BarManager.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/17.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Cocoa

class BarManager {
    static let `default` = BarManager.init()
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var watch: SKQueue?
    private var deviceInfoWatch: FileWatch?
    /*
     监控设备、模拟器数量、App数量，可能watch和deviceInfoWatch短时间内给出多个回调
     增加该变量，控制刷新频率
     */
    private var waitRefreshNum = 0
    private init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.image = #imageLiteral(resourceName: "statusItem_icon")
        statusItem.image?.isTemplate = true
        statusItem.menu = menu
        addWatch()
        refresh()
        self.commonItems.forEach({ (item) in
            self.menu.addItem(item)
        })
    }
    
    private func addWatch() {
        watch = SKQueue({ [weak self] (noti, _) in
            if noti.contains(.Write) && noti.contains(.SizeIncrease) {
                self?.refresh(wait: 1)
            }
        })
    }
    
    func refresh(wait deadline: Double = 0) {
        waitRefreshNum = waitRefreshNum + 1
        defaultSubQueue.asyncAfter(deadline: .now() + deadline) {
            self.waitRefreshNum = self.waitRefreshNum - 1
            if self.waitRefreshNum != 0{
                return
            }
            let deviceItems = self.deviceItems()
            DispatchQueue.main.async {
                self.menu.removeAllItems()
                deviceItems.forEach({ (item) in
                    self.menu.addItem(item)
                })
                if deviceItems.isEmpty {
                    let xcodeSelectItem = NSMenuItem(title: "Xcode Select...", action: #selector(self.preference(_:)), keyEquivalent: "")
                    xcodeSelectItem.target = self
                    self.menu.addItem(xcodeSelectItem)
                }
                self.menu.addItem(NSMenuItem.separator())
                self.commonItems.forEach({ (item) in
                    self.menu.addItem(item)
                })
            }
        }
    }
    
    private func deviceItems() -> [NSMenuItem] {
        watch?.removeAllPaths()
        watch?.addPath(Device.url.path) // 模拟器数量监控
        var deviceInfoURLPath: [String] = [] // 模拟器开关状态监控
        var items: [NSMenuItem] = []
        var hasAppDeviceItemDic: [String: [NSMenuItem]] = [:]
        var emptyAppDeviceItemDic: [String: [NSMenuItem]] = [:]
        TotalModel.default.update()
        TotalModel.default.runtimes.forEach { (r) in
            var hasAppDeviceItems: [NSMenuItem] = []
            var emptyAppDeviceItems: [NSMenuItem] = []
            let devices = r.devices
            devices.forEach({ (device) in
                deviceInfoURLPath.append(device.infoURL.path)
                self.watch?.addPath(device.dataURL.path) // 模拟器App数量监控
                if FileManager.default.fileExists(atPath: device.bundleURL.path) {
                    self.watch?.addPath(device.bundleURL.path)
                }
                let deviceItem = DeviceMenuItem(device)
                if deviceItem.isEmptyApp {
                    hasAppDeviceItems.append(deviceItem)
                }else{
                    emptyAppDeviceItems.append(deviceItem)
                }
            })
            if !hasAppDeviceItems.isEmpty {
                let titleItem = NSMenuItem(title: r.name, action: nil, keyEquivalent: "")
                titleItem.isEnabled = false
                hasAppDeviceItems.insert(titleItem, at: 0)
                hasAppDeviceItemDic[r.name] = hasAppDeviceItems
            }
            if !emptyAppDeviceItems.isEmpty{
                let titleItem = NSMenuItem(title: r.name, action: nil, keyEquivalent: "")
                titleItem.isEnabled = false
                emptyAppDeviceItems.insert(titleItem, at: 0)
                emptyAppDeviceItemDic[r.name] = emptyAppDeviceItems
            }
        }
        DispatchQueue.main.async {
            self.deviceInfoWatch = try? FileWatch(paths: deviceInfoURLPath, createFlag: [.UseCFTypes, .FileEvents], runLoop: .current, latency: 1, eventHandler: { [weak self] (event) in
                if event.flag.contains(.ItemIsFile) && event.flag.contains(.ItemRenamed) {
                    self?.refresh(wait: 0.5)
                }
            })
        }
        let sortKeys = hasAppDeviceItemDic.keys.sorted()
        for key in sortKeys{
            items.append(contentsOf: hasAppDeviceItemDic[key]!)
        }
        let deviceTypeItem = DeviceTypeCreateItem()
        if !emptyAppDeviceItemDic.isEmpty && !deviceTypeItem.submenu!.items.isEmpty {
            items.append(NSMenuItem.separator())
        }
        if !emptyAppDeviceItemDic.isEmpty{
            let otherDeviceItem = NSMenuItem(title: "Other Simulators", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            otherDeviceItem.submenu = submenu
            let sortKeys = emptyAppDeviceItemDic.keys.sorted()
            for key in sortKeys{
                emptyAppDeviceItemDic[key]?.forEach({ (item) in
                    submenu.addItem(item)
                })
            }
            items.append(otherDeviceItem)
        }
        
        if !deviceTypeItem.submenu!.items.isEmpty{
            items.append(deviceTypeItem)
        }
        return items
    }
    
    @objc private func deviceOnOrOff(_ sender: NSMenuItem) {
        if let device = sender.representedObject as? Device {
            switch device.state {
            case .booted:
                try? device.shutdown()
            case .shutdown:
                try? device.boot()
            }
        }
    }
    
    //MARK: - Common Items and Actions
    private lazy var commonItems: [NSMenuItem] = {
        var items: [NSMenuItem] = []
        let preMenu = NSMenuItem(title: "Preferences...", action: #selector(preference(_:)), keyEquivalent: ",")
        preMenu.target = self
        items.append(preMenu)
        let refreshMenu = NSMenuItem(title: "Refresh", action: #selector(refresh(_:)), keyEquivalent: "r")
        refreshMenu.target = self
        items.append(refreshMenu)
        let quitMenu = NSMenuItem(title: "Quit", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitMenu.target = self
        items.append(quitMenu)
        return items
    }()
    
    @objc private func refresh(_ sender: Any) {
        TotalModel.default.isForceUpdate = true
        self.refresh()
    }
    
    @objc private func quitApp(_ sender: Any) {
        NSApp.terminate(nil)
    }
    
    private var preferenceWindowController: NSWindowController?
    @objc private func preference(_ sender: NSMenuItem) {
        if let controller = preferenceWindowController {
            controller.close()
        }
        let title = sender.title
        if title == "Xcode Select..." {
            PreferencesWindowController.firstTabSelectIdentifier = "Xcode Select"
        }else{
            PreferencesWindowController.firstTabSelectIdentifier = "General"
        }
        preferenceWindowController = NSStoryboard.init(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Preferences")) as? NSWindowController
        NSApp.activate(ignoringOtherApps: true)
        preferenceWindowController?.window?.makeKeyAndOrderFront(NSApplication.shared)
    }
}
