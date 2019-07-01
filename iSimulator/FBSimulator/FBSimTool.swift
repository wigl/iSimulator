//
//  FBSimTool.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/11/8.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import FBSimulatorControl

class FBSimTool {
    
    static let `default` = FBSimTool()
    
    private var allSimulators: [FBSimulator] {
        get{
            return self.control?.set.allSimulators ?? []
        }
    }
    
    var control: FBSimulatorControl? = {
        let options = FBSimulatorManagementOptions()
        let logger = FBControlCoreGlobalConfiguration.defaultLogger
        let config = FBSimulatorControlConfiguration.init(deviceSetPath: nil, options: options, logger: logger, reporter: nil)
        let control = try? FBSimulatorControl.withConfiguration(config)
        return control
    }()
    
    func boot(_ udid: String) throws {
        let sims = allSimulators.filter { $0.udid == udid }
        if let sim = sims.first {
            let future = sim.boot()
            try future.await(withTimeout: 20)
            sim.focus()
        }else{
            throw NSError.init(domain: "Boot Failed!", code: -1, userInfo: nil)
        }
    }
    
    func shutdown(_ udid: String) throws {
        let sims = allSimulators.filter { $0.udid == udid }
        if let sim = sims.first {
            sim.shutdown()
        }else{
            throw NSError.init(domain: "Shutdown Failed!", code: -1, userInfo: nil)
        }
    }
    
    func erase(_ udid: String) throws {
        let sims = allSimulators.filter { $0.udid == udid }
        if let sim = sims.first {
            sim.erase()
        }else{
            throw NSError.init(domain: "Erase Failed!", code: -1, userInfo: nil)
        }
    }
    
    func delete(_ udid: String) throws {
        let sims = allSimulators.filter { $0.udid == udid }
        if let sim = sims.first {
            control?.set.delete(sim)
        }else{
            throw NSError.init(domain: "Delete Failed!", code: -1, userInfo: nil)
        }
    }
    
    func uninstallApp(deviceUdid: String, appBundleID: String) throws {
        let sims = allSimulators.filter { $0.udid == deviceUdid }
        if let sim = sims.first {
            let _ = sim.uninstallApplication(withBundleID: appBundleID)
        }else{
            throw NSError.init(domain: "Uninstall Failed!", code: -1, userInfo: nil)
        }
    }
    
    func killApp(deviceUdid: String, appBundleID: String) throws {
        let sims = allSimulators.filter { $0.udid == deviceUdid }
        if let sim = sims.first {
            let _ = sim.killApplication(withBundleID: appBundleID)
        }else{
            throw NSError.init(domain: "Terminate Failed!", code: -1, userInfo: nil)
        }
    }

    func launchApp(device: Device, app: Application) throws {
        let sims = allSimulators.filter { $0.udid == device.udid }
        if let sim = sims.first {
            let appLunch = FBApplicationLaunchConfiguration.init(bundleID: app.bundleID, bundleName: app.bundleDisplayName, arguments: [], environment: [:], output: FBProcessOutputConfiguration.defaultOutputToFile(), launchMode: .foregroundIfRunning)
            let _ = sim.launchApplication(appLunch)
        }else{
            throw NSError.init(domain: "Lunch Failed!", code: -1, userInfo: nil)
        }
    }
    
}
