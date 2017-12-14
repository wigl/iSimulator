//
//  TotalModel.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import ObjectMapper

class TotalModel: Mappable {
    static let `default` = TotalModel()
    var isForceUpdate = true
    var lastXcodePath = ""
    var isXcode9OrGreater = false
    
    func updateXcodeVersion() {
        var url = URL.init(fileURLWithPath: lastXcodePath)
        url.deleteLastPathComponent()
        url.appendPathComponent("Info.plist")
        guard let appInfoDict = NSDictionary(contentsOf: url),
            let version = appInfoDict["CFBundleShortVersionString"] as? String else {
                return
        }
        let versionNumber = NSDecimalNumber.init(string: version)
        let result = versionNumber.compare(NSDecimalNumber.init(string: "9.0"))
        if result != .orderedAscending {
            isXcode9OrGreater = true
        }
    }
    
    ///该方法： 耗时 && 阻塞
    func update() {
        let xcodePath = shell("/usr/bin/xcrun", arguments: "xcode-select", "-p").0
        if lastXcodePath != xcodePath{
            isForceUpdate = true
            lastXcodePath = xcodePath
            updateXcodeVersion()
        }
        if isForceUpdate {
            isForceUpdate = false
            Device.bundleURLAppsCache = [:]
            Device.sandboxURLs = []
            let contents = try? FileManager.default.contentsOfDirectory(at: Device.linkURL, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])
            if let contents = contents{
                for url in contents {
                    if let last = url.pathComponents.last,
                        last == "Icon\r"{
                        try? FileManager.default.removeItem(at: Device.linkURL)
                    }
                }
            }
            
            try? FileManager.default.removeItem(at: Device.linkURL)
            try? FileManager.default.createDirectory(at: Device.linkURL, withIntermediateDirectories: true)
            NSWorkspace.shared.setIcon(#imageLiteral(resourceName: "linkDirectory"), forFile: Device.linkURL.path, options:[])
        }
        let jsonStr = shell("/usr/bin/xcrun", arguments: "simctl", "list", "-j").0
        _ = Mapper().map(JSONString: jsonStr, toObject: TotalModel.default)
    }
    
    var runtimes: [Runtime] = []
    func runtimes(osType: Runtime.OSType) -> [Runtime] {
        return runtimes.filter{$0.name.contains(osType.rawValue)}
    }
    
    var devicetypes: [DeviceType] = []
    var iOSDevicetypes: [DeviceType] {
        return devicetypes.filter{$0.name.contains("iPhone") || $0.name.contains("iPad")}
    }
    var tvOSDevicetypes: [DeviceType] {
        return devicetypes.filter{$0.name.contains("TV")}
    }
    var watchOSDevicetypes: [DeviceType] {
        return devicetypes.filter{$0.name.contains("Watch")}
    }
    
    private var devices: [String: [Device]] = [:]
    
    private var pairs: [String: Pair] = [:]
    
    private init() { }
    
    required init?(map: Map) { }
    
    func mapping(map: Map) {
        runtimes.removeAll()
        devicetypes.removeAll()
        devices.removeAll()
        pairs.removeAll()
        runtimes <- map["runtimes"]
        devicetypes <- map["devicetypes"]
        devices <- map["devices"]
        pairs <- map["pairs"]
        // 关联 runtime 和 device/devicetype
        runtimes.forEach{ r in
            r.devices = self.devices[r.name] ?? []
            switch r.osType {
            case .iOS:
                r.devicetypes = self.iOSDevicetypes
            case .watchOS:
                r.devicetypes = self.watchOSDevicetypes
            case .tvOS:
                r.devicetypes = self.tvOSDevicetypes
            case .None:
                break
            }
            r.devices.forEach{
                $0.runtime = r
                //⚠️⚠️关联之后，再更新device的APP，否则取不到device的runtime⚠️⚠️
                $0.updateApps()
            }
        }
        // 关联pair
        var tempAllDevice: [Device] = []
        devices.forEach { (_, value) in
            tempAllDevice.append(contentsOf: value)
        }
        pairs.forEach { (key, pair) in
            let watchDevices = tempAllDevice.filter({ (device) -> Bool in
                if let watch = pair.watch{
                    return device.udid == watch.udid
                }
                return false
            })
            let phoneDevices = tempAllDevice.filter({ (device) -> Bool in
                if let phone = pair.phone{
                    return device.udid == phone.udid
                }
                return false
            })
            if let phone = phoneDevices.first, let watch = watchDevices.first{
                watch.pairUDID = key
                phone.pair.append(watch)
            }
        }
        // 更新缓存
        Device.sandboxURLs = []
        var bundleURLAppsCacheTemp: [URL: Application] = [:]
        var sandboxURLsTemp: Set<URL> = []
        devices.forEach { (_, arr) in
            arr.forEach({ (d) in
                d.applications.forEach({ (app) in
                    //添加至临时缓存
                    bundleURLAppsCacheTemp[app.bundleDirUrl] = app
                    sandboxURLsTemp.insert(app.sandboxDirUrl)
                    //从旧的缓存中移除
                    Device.bundleURLAppsCache.removeValue(forKey: app.bundleDirUrl)
                    Device.sandboxURLs.remove(app.sandboxDirUrl)
                })
            })
        }
        // 缓存中剩余的App删除linkDir
        // 不在app deinit 方法里面 removeLinkDir， 因为deinit方法调用有延迟
        Device.bundleURLAppsCache.forEach{$0.value.removeLinkDir()}
        Device.bundleURLAppsCache = bundleURLAppsCacheTemp
        Device.sandboxURLs = sandboxURLsTemp
    }
}
