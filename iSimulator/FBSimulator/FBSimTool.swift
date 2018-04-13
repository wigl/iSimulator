//
//  FBSimTool.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/11/8.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

/*
 Update Date:
 Commits on Apr 6, 2018
 commit 7a42a91e7175223cbf218757b94df75ab19b51a5
 
 FBSimulatorEventRelay.m:102  -> NSParameterAssert(self.connection == nil);
 
 FBWeakFramework.m:358 -> return [[FBControlCoreError
 */

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
        let config = FBSimulatorControlConfiguration(deviceSetPath: nil, options: options)
        let logger = FBControlCoreGlobalConfiguration.defaultLogger
        let control = try? FBSimulatorControl.withConfiguration(config, logger: logger)
        return control
    }()
    
    func boot(_ udid: String) throws {
        let sims = allSimulators.filter { $0.udid == udid }
        if let sim = sims.first {
            let future = sim.boot()
            try future.await(withTimeout: 20)
            try sim.focus()
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
            let bundle = FBApplicationBundle.init(name: app.bundleDisplayName, path: app.appUrl.path, bundleID: app.bundleID, binary: nil)
            let appLunch = FBApplicationLaunchConfiguration.init(application: bundle, arguments: [], environment: [:], waitForDebugger: false, output: FBProcessOutputConfiguration.defaultOutputToFile())
            let _ = sim.launchApplication(appLunch)
        }else{
            throw NSError.init(domain: "Lunch Failed!", code: -1, userInfo: nil)
        }
    }
    
}
