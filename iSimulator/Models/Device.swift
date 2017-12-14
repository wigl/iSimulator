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
    // 当设备为iPhone时候，配对的watch
    var pair: [Device] = []
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
    /// 用于监控Device状态
    var infoURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/device.plist")
    }
    /// 暂未使用
    fileprivate var iconStateURL: URL {
        return Device.url.appendingPathComponent("\(self.udid)/data/Library/SpringBoard/IconState.plist")
    }
    
    init() { }
    
    required init?(map: Map) { }
    
    func mapping(map: Map) {
        state <- (map["state"], EnumTransform())
        availability <- (map["availability"], EnumTransform())
        name <- map["name"]
        udid <- map["udid"]
    }
}

// MARK: - device 操作
extension Device {
    func boot() throws {
//        shell("/usr/bin/xcrun", arguments: "simctl", "boot", self.udid)
//        var xcode = TotalModel.default.lastXcodePath
//        if xcode.hasSuffix("\n"){
//            xcode = String(xcode.dropLast())
//        }
//        let simPath = xcode.appending("/Applications/Simulator.app")
//        shell("/usr/bin/xcrun", arguments: "open", simPath)
        try? FBSimTool.default.boot(self.udid)
    }
    
    func shutdown() throws {
        try? FBSimTool.default.shutdown(self.udid)
//        shell("/usr/bin/xcrun", arguments: "simctl", "shutdown", self.udid)
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
    
    func installApp(_ path: String) {
        if self.state == .shutdown {
            try? self.boot()
        }
        shell("/usr/bin/xcrun", arguments: "simctl", "install", self.udid, path)
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
            BarManager.default.refresh()
        }
    }
}


// MARK: - 获取APP：方式1
extension Device {
    /// 以app的boundleURL为key，缓存
    static var bundleURLAppsCache: [URL: Application] = [:]
    /// 缓存的sandboxURL
    static var sandboxURLs: Set<URL> = []
    /// 需要忽略的 boundleURL/sandboxURL：如无效的文件夹
    private static var ignorePaths: Set<URL> = []
    
    func updateApps() {
        self.applications = []
        let idAndBundleUrlDic = identifierAndUrl(with: bundleURL)
        var idAndSandboxUrlDic = identifierAndUrl(with: sandboxURL)
        idAndBundleUrlDic.forEach { (bundleID, bundleDirUrl) in
            guard let sandboxDirUrl = idAndSandboxUrlDic[bundleID] else {
                return
            }
            if let app = Application(bundleID: bundleID, bundleDirUrl: bundleDirUrl, sandboxDirUrl: sandboxDirUrl){
                app.device = self
                self.applications.append(app)
                idAndSandboxUrlDic.removeValue(forKey: bundleID)
            }else{
                Device.ignorePaths.insert(bundleDirUrl)
            }
        }
        idAndSandboxUrlDic.forEach({ (_, url) in
            Device.ignorePaths.insert(url)
        })
        // ⚠️⚠️所有app赋值成功后，再创建linkDir，否则无法判断app.bundleDisplayName是否重复⚠️⚠️
        self.applications.forEach{$0.createLinkDir()}
    }
    
    private func identifierAndUrl(with url: URL) -> [String: URL] {
        let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        guard let contentArr = contents, !contentArr.isEmpty else {
            return [:]
        }
        var dic: [String: URL] = [:]
        contentArr.forEach { (url) in
            if  Device.ignorePaths.contains(url) {
                return
            }
            if let app = Device.bundleURLAppsCache[url] {
                app.device = self
                self.applications.append(app)
                return
            }
            if Device.sandboxURLs.contains(url) {
                return
            }
            if let contents = NSDictionary(contentsOf: url.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")),
                let identifier = contents["MCMMetadataIdentifier"] as? String {
                dic[identifier] = url
            }else{
                Device.ignorePaths.insert(url)
            }
        }
        return dic
    }
}


private let kUserDefaultDocumentKey = "kUserDefaultDocumentKey"
private let kDocumentName = "iSimulator"
// MARK: - Device目录
extension Device {
    static let url: URL = {
        let userLibraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return userLibraryURL.appendingPathComponent("Developer/CoreSimulator/Devices")
    }()
    /// 暂未使用
    private static let setURL: URL = {
        return url.appendingPathComponent("device_set.plist")
    }()
    
    static func updateDocumentURL(path: String, finish:@escaping (_ error: String?)->Void) {
        if !FileManager.default.fileExists(atPath: path) {
            finish("Folder doesn't exist!")
            return
        }
        let linkURL = URL(fileURLWithPath: path).appendingPathComponent(kDocumentName)
        defaultSubQueue.async {
            DispatchQueue.main.async {
                do {
                    try FileManager.default.moveItem(at: self.linkURL, to: linkURL)
                    Device.linkURL = linkURL
                    UserDefaults.standard.set(path, forKey: kUserDefaultDocumentKey)
                    UserDefaults.standard.synchronize()
                    finish(nil)
                } catch {
                    finish(error.localizedDescription)
                }
            }
        }
        
    }
    
    static var linkURL: URL = {
        var url: URL
        if let path = UserDefaults.standard.string(forKey: kUserDefaultDocumentKey) {
            url = URL(fileURLWithPath: path)
        }else{
            url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        url.appendPathComponent(kDocumentName)
        return url
    }()
    
}

// MARK: - 获取安装的APP：方式2，暂未使用
extension Device {
    //⚠️⚠️还有问题没解决：simctl appinfo返回的数据格式不是jison⚠️⚠️
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
    
    private func fetchAppInfo(deviceId: String, appBunldId: String) -> [String: Any] {
        let jsonStr = shell("/usr/bin/xcrun", arguments: "simctl", "appinfo", deviceId, appBunldId).0
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
