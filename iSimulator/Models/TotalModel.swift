//
//  TotalModel.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import AppKit
import ObjectMapper

class TotalModel: Mappable {
    static let `default` = TotalModel()
    var isForceUpdate = true
    var lastXcodePath = ""
    var isXcode9OrGreater = false
    var appCache = ApplicationCache()
    
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
        let xcodePath = shell("/usr/bin/xcrun", arguments: "xcode-select", "-p").outStr
        if lastXcodePath != xcodePath{
            isForceUpdate = true
            lastXcodePath = xcodePath
            updateXcodeVersion()
        }
        if isForceUpdate {
            isForceUpdate = false
            appCache = ApplicationCache()
            let contents = try? FileManager.default.contentsOfDirectory(at: RootLink.url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])
            if let contents = contents{
                for url in contents {
                    if let last = url.pathComponents.last,
                        last == "Icon\r"{
                        try? FileManager.default.removeItem(at: RootLink.url)
                    }
                }
            }
            
            try? FileManager.default.createDirectory(at: RootLink.url, withIntermediateDirectories: true)
            NSWorkspace.shared.setIcon(#imageLiteral(resourceName: "linkDirectory"), forFile: RootLink.url.path, options:[])
        }
        let jsonStr = shell("/usr/bin/xcrun", arguments: "simctl", "list", "-j").outStr
        _ = Mapper().map(JSONString: jsonStr, toObject: TotalModel.default)
    }
    
    var runtimes: [Runtime] = []
    func runtimes(osType: Runtime.OSType) -> [Runtime] {
        return runtimes.filter{$0.name.contains(osType.rawValue)}
    }
    
    private var devicetypes: [DeviceType] = []
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
                $0.updateApps(with: appCache)
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
            if let phone = phoneDevices.first, let watch = watchDevices.first {
                if watch.runtime == nil || phone.runtime == nil {
                    //上报错误
                    LogReport.default.runtimeNilReport()
                } else {
                    watch.pairUDID = key
                    phone.pair.append(watch)
                }
            }
        }
        // 更新缓存
        self.updateCache()
        // 更新log状态
        LogReport.default.logSimctlList()
    }
    
    func updateCache() {
        let applications = runtimes.flatMap { $0.devices }.flatMap { $0.applications }
        
        var urlAndAppDicCache: [URL: Application] = [:]
        var sandboxURLsCache: Set<URL> = []
        
        applications.forEach { (app) in
            //添加至临时缓存
            urlAndAppDicCache[app.bundleDirUrl] = app
            sandboxURLsCache.insert(app.sandboxDirUrl)
            //从旧的缓存中移除
            self.appCache.urlAndAppDic.removeValue(forKey: app.bundleDirUrl)
            self.appCache.sandboxURLs.remove(app.sandboxDirUrl)
        }
        // 删除不存在的app虚拟文件夹
        // 不在app deinit 方法里面 removeLinkDir， 因为deinit方法调用有延迟
        self.appCache.urlAndAppDic.forEach { $0.value.removeLinkDir() }
        
        self.appCache.urlAndAppDic = urlAndAppDicCache
        self.appCache.sandboxURLs = sandboxURLsCache
    }
    
    var dataReportDic: [String: Any] {
        let r = runtimes.map { $0.dataReportDic }
        let dt = devicetypes.map { $0.dataReportDic }
        let d = devices.mapValues {
            $0.map({
                $0.dataReportDic
            })
        }
        let p = pairs.mapValues {
            $0.dataReportDic
        }
        return ["r": r, "dt": dt, "d": d, "p": p]
    }
}
