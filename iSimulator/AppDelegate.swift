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
 UI参考：
 https://github.com/noodlewerk/NWPusher
 https://github.com/shadowsocks/ShadowsocksX-NG
 https://github.com/lhc70000/iina
 1. 创建模拟器的输入模拟器名字，分辨不同的runtime和模拟器是否可以创建
 */

import Cocoa

let defaultSubQueue = DispatchQueue(label: "defaultSubQueue")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let barManager = BarManager.default
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
    }

}

