//
//  AppDelegate.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/17.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

/*
 获取模拟器参考：
 https://github.com/facebook/FBSimulatorControl
 https://github.com/fastlane/fastlane
 https://github.com/luosheng/OpenSim
 https://github.com/lincf0912/iSimulator
 UI参考：
 https://github.com/noodlewerk/NWPusher
 https://github.com/shadowsocks/ShadowsocksX-NG
 https://github.com/lhc70000/iina
 1. 创建模拟器的输入模拟器名字，分辨不同的runtime和模拟器是否可以创建
 */

import Cocoa
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var barManager: BarManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if DEBUG
        
        #else
            UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
            Crashlytics.start(withAPIKey: "c8a105a14acb1ea410f25dfec3f84a343fbd2f05")
        #endif
        
        self.barManager = BarManager.default
    }

}

