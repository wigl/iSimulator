//
//  Device.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import ObjectMapper

class Device: Mappable {
    enum State: String {
        case booted = "Booted"
        case shutdown = "Shutdown"
    }
    var state = State.shutdown
    var availability = Availability.unavailable
    var name = ""
    var udid = ""
    var applications: [Application] = []
    var appGroups: [AppGroup] = []
    // 当设备为iPhone时候，配对的watch
    var pairs: [Device] = []
    // 当设备为watch的时候，配对UDID
    var pairUDID: String?
    weak var runtime: Runtime!
    /// 用于监控Device被抹掉的改变
    var dataURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data")
    }
    var sandboxURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data/Containers/Data/Application")
    }
    var bundleURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data/Containers/Bundle/Application")
    }
    var appGroupURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data/Containers/Shared/AppGroup")
    }
    /// 用于监控Device状态
    var infoURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/device.plist")
    }
    
    init() {
        
    }
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        state <- (map["state"], EnumTransform())
        availability <- (map["availability"], EnumTransform())
        name <- map["name"]
        udid <- map["udid"]
    }
    
    var dataReportDic: [String: String] {
        return ["n": name, "id": udid]
    }
}

extension Device {
    
    static let url: URL = {
        let userLibraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return userLibraryURL.appendingPathComponent("Developer/CoreSimulator/Devices")
    }()
    
    static let setURL: URL = {
        return url.appendingPathComponent("device_set.plist")
    }()
}

// MARK: - device Action
extension Device {
    func boot() throws {
        //        shell("/usr/bin/xcrun", arguments: "simctl", "boot", self.udid)
        try? FBSimTool.default.boot(self.udid)
    }
    
    func shutdown() throws {
        //        shell("/usr/bin/xcrun", arguments: "simctl", "shutdown", self.udid)
        try? FBSimTool.default.shutdown(self.udid)
    }
    
    func erase() throws {
        if self.state == .booted {
            try? self.shutdown()
        }
        var afterTime = 0.0
        if self.state == .booted {
            afterTime = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + afterTime) {
            shell("/usr/bin/xcrun", arguments: "simctl", "erase", self.udid)
        }
    }
    
    func delete() throws {
        shell("/usr/bin/xcrun", arguments: "simctl", "delete", self.udid)
    }
    
    func installApp(_ app: Application) {
        if self.state == .shutdown {
            try? self.boot()
        }
        shell("/usr/bin/xcrun", arguments: "simctl", "terminate", self.udid, app.bundleID)
        shell("/usr/bin/xcrun", arguments: "simctl", "install", self.udid, app.appUrl.path)
    }
    
    func launch(appBundleId: String) {
        if self.state == .shutdown {
            try? self.boot()
        }
        shell("/usr/bin/xcrun", arguments: "simctl", "launch", self.udid, appBundleId)
    }
    
    func unpair() {
        if let udid = self.pairUDID{
            shell("/usr/bin/xcrun", arguments: "simctl", "unpair", udid)
        }
    }
    func pair(to device: Device) {
        shell("/usr/bin/xcrun", arguments: "simctl", "pair", self.udid, device.udid)
    }
}

extension Device {
    
    func updateAppGroups(with cache: AppGroupCache) {
        let appGroupContents = (try? FileManager.default.contentsOfDirectory(at: appGroupURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])) ?? []
        var appGroups: [AppGroup] = []
        appGroupContents.enumerated().forEach { (offset, url) in
            let group = cache.groups.first { (appGroup) -> Bool in
                appGroup.fileURL == url
            }
            if let appGroup = group {
                appGroups.append(appGroup)
            } else {
                if let id = identifier(with: url) {
                    let appGroup = AppGroup.init(fileURL: url, id: id)
                    appGroups.append(appGroup)
                }
            }
        }
        appGroups = appGroups.filter { !$0.id.contains("com.apple") }
        self.appGroups = appGroups
        DispatchQueue.main.async {
            self.appGroups.forEach{ $0.createLinkDir(device: self) }
        }
    }
}


// MARK: - 获取APP：方式1
extension Device {
    
    func updateApps(with cache: ApplicationCache) {
        let bundleContents = (try? FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])) ?? []
        
        let sandboxContents = (try? FileManager.default.contentsOfDirectory(at: sandboxURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])) ?? []
        
        var apps: [Application] = []
        
        // 优先从缓存中取
        var newBundles = [URL]()
        bundleContents.enumerated().forEach { (offset, url) in
            if let app = cache.urlAndAppDic[url] {
                app.device = self
                apps.append(app)
            } else if cache.ignoreURLs.contains(url) {
                //忽略
            } else {
                newBundles.append(url)
            }
        }
        
        var newSandboxs = [URL]()
        sandboxContents.enumerated().forEach { (offset, url) in
            if cache.sandboxURLs.contains(url) || cache.ignoreURLs.contains(url) {
                //忽略
            } else {
                newSandboxs.append(url)
            }
        }
        
        let idAndBundleUrlDic = identifierAndUrl(with: newBundles)
        var idAndSandboxUrlDic = identifierAndUrl(with: newSandboxs)
        
        idAndBundleUrlDic.forEach { (bundleID, bundleDirUrl) in
            guard let sandboxDirUrl = idAndSandboxUrlDic.removeValue(forKey: bundleID) else {
                return
            }
            if let app = Application(bundleID: bundleID, bundleDirUrl: bundleDirUrl, sandboxDirUrl: sandboxDirUrl){
                app.device = self
                apps.append(app)
            } else {
                cache.ignoreURLs.insert(bundleDirUrl)
            }
        }
        idAndSandboxUrlDic.forEach({ (_, url) in
            cache.ignoreURLs.insert(url)
        })
        self.applications = apps
        // ⚠️⚠️所有app赋值成功后，再创建linkDir，否则无法判断app.bundleDisplayName是否重复⚠️⚠️
        DispatchQueue.main.async {
          self.applications.forEach{ $0.createLinkDir() }
        }
    }
    
    private func identifierAndUrl(with urls: [URL]) -> [String: URL] {
        var dic: [String: URL] = [:]
        urls.forEach { (url) in
            if let identifier = self.identifier(with: url) {
                dic[identifier] = url
            }
        }
        return dic
    }
    
    private func identifier(with url: URL) -> String? {
        if let contents = NSDictionary(contentsOf: url.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")),
            let identifier = contents["MCMMetadataIdentifier"] as? String {
            return identifier
        }
        return nil
    }
}

// MARK: - 获取安装的APP：方式2，暂未使用
extension Device {
    
    private var iconStateURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data/Library/SpringBoard/IconState.plist")
    }
    
    private func allApps2() -> [Application] {
        var apps: [Application] = []
        guard let dic = NSDictionary(contentsOf: iconStateURL) as? [String: Any] else {
            return []
        }
        let icons = getAllAppIds(from: dic)
        icons.forEach { (id) in
            let dic = fetchAppInfo(deviceId: self.udid, appBunldId: id)
            guard let bundleID = dic["CFBundleIdentifier"] as? String,
                let bundleDirStr = dic["CFBundleIdentifier"] as? String,
                let bundleDirUrl = URL(string: bundleDirStr),
                let sandboxDirStr = dic["DataContainer"] as? String,
                let sandboxDirUrl = URL(string: sandboxDirStr),
                let app = Application(bundleID: bundleID, bundleDirUrl: bundleDirUrl, sandboxDirUrl: sandboxDirUrl) else {
                    return
            }
            apps.append(app)
        }
        return apps
    }
    
    //⚠️⚠️simctl appinfo返回的数据格式不是json, 且device必须是booted的，否则获取不到信息⚠️⚠️
    private func fetchAppInfo(deviceId: String, appBunldId: String) -> [String: Any] {
        let jsonStr = shell("/usr/bin/xcrun", arguments: "simctl", "appinfo", deviceId, appBunldId).outStr
        let data = jsonStr.data(using: .utf8, allowLossyConversion: true)
        if let data = data {
            let parsedJSON = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
            if let dic = parsedJSON as? [String: Any]{
                return dic
            }
        }
        return [:]
    }
    
    private func getAllAppIds(from dic: [String: Any]) -> [String] {
        guard let iconLists = dic["iconLists"] as? [[Any]] else {
            return []
        }
        var icons: [String] = []
        iconLists.forEach { (page) in
            page.forEach({ (item) in
                if let id = item as? String,
                    !id.contains("com.apple") {
                    icons.append(id)
                }
                if let dic = item as? [String: Any] {
                    let iconsTemp = getAllAppIds(from: dic)
                    icons.append(contentsOf: iconsTemp)
                }
            })
        }
        return icons
    }
}
