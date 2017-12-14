//
//  Application.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Cocoa

private let appOriginImage = #imageLiteral(resourceName: "default_ios_app_icon").appIcon(h: 512)
private let appImage = #imageLiteral(resourceName: "default_ios_app_icon").appIcon()

class Application {
    let bundleID: String
    let bundleDirUrl: URL //.app文件所在目录URL
    let sandboxDirUrl: URL //沙盒文件目录URL
    let appUrl: URL //.app 的url
    let bundleDisplayName: String
    let bundleShortVersion: String
    let bundleVersion: String
    let image: NSImage
    let originImage: NSImage
    weak var device: Device!
    var linkURL:URL?
    lazy var attributeStr: NSMutableAttributedString = {
        let name = "\(self.bundleDisplayName) - \(self.bundleShortVersion)(\(self.bundleVersion))"
        let other = "\n\(self.bundleID)"
        let att = NSMutableAttributedString(string: name + other)
        att.addAttributes([NSAttributedStringKey.font: NSFont.systemFont(ofSize: 13)], range: NSRange(location: 0, length: name.count))
        att.addAttributes([NSAttributedStringKey.font: NSFont.systemFont(ofSize: 11), NSAttributedStringKey.foregroundColor: NSColor.lightGray], range: NSRange(location: name.count, length: other.count))
        return att
    }()
    
    init?(bundleID: String, bundleDirUrl: URL, sandboxDirUrl: URL) {
        self.bundleID = bundleID
        self.bundleDirUrl = bundleDirUrl
        self.sandboxDirUrl = sandboxDirUrl
        guard let contents = try? FileManager.default.contentsOfDirectory(at: bundleDirUrl, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            else {
                return nil
        }
        var appURLTemp: URL?
        for url in contents{
            if url.pathExtension == "app" {
                appURLTemp = url
                break
            }
        }
        guard let appURL = appURLTemp else { return nil }
        
        let appInfoURL = appURL.appendingPathComponent("Info.plist")
        guard let appInfoDict = NSDictionary(contentsOf: appInfoURL),
            let aBundleID = appInfoDict["CFBundleIdentifier"] as? String,
            let aBundleDisplayName = (appInfoDict["CFBundleDisplayName"] as? String) ?? (appInfoDict["CFBundleName"] as? String) else {
                return nil
        }
        if aBundleID != bundleID {
            return nil
        }
        let aBundleShortVersion = appInfoDict["CFBundleShortVersionString"] as? String ?? "NULL"
        let aBundleVersion = appInfoDict["CFBundleVersion"] as? String ?? "NULL"
        self.appUrl = appURL
        bundleDisplayName = aBundleDisplayName
        bundleShortVersion = aBundleShortVersion
        bundleVersion = aBundleVersion
        var iconFiles = ((appInfoDict["CFBundleIcons"] as? NSDictionary)?["CFBundlePrimaryIcon"] as? NSDictionary)?["CFBundleIconFiles"] as? [String]
        if iconFiles == nil {
            iconFiles = ["Icon.png"]
        }
        if let imageStr = iconFiles?.last,
            let bundle = Bundle(url: appUrl),
            let im = bundle.image(forResource: NSImage.Name(rawValue: imageStr)) {
            originImage = im
            image = im.appIcon()
        }else{
            originImage = appOriginImage
            image = appImage
        }
    }
}


// MARK: - Application 操作
extension Application {
    
    func launch() {
        if device.state == .shutdown {
            try? device.boot()
        }
        shell("/usr/bin/xcrun", arguments: "simctl", "launch", device.udid, bundleID)
    }
    
    func terminate() {
        shell("/usr/bin/xcrun", arguments: "simctl", "terminate", device.udid, bundleID)
    }
    
    func uninstall() throws {
        self.terminate()
        shell("/usr/bin/xcrun", arguments: "simctl", "uninstall", device.udid, bundleID)
    }
    
    func size(_ closure: @escaping (_ sandboxSize: UInt64, _ bundleSize: UInt64)-> Void) {
        DispatchQueue.global().async {
            //            closure(self.sizeOfDirectory(self.sandboxDirUrl), self.sizeOfDirectory(self.bundleDirUrl))
        }
    }
    
    private func sizeOfDirectory(_ dir: URL) -> UInt64 {
        var size: UInt64 = 0
        let filesEnumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil, options: [], errorHandler: { (url, error) -> Bool in
            return true
        })
        while let fileUrl = filesEnumerator?.nextObject() as? URL {
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileUrl.path) as NSDictionary
            size += attributes?.fileSize() ?? 0
        }
        return size
    }
}

// MARK: - 虚拟文件夹创建/删除
extension Application {
    func createLinkDir() {
        if self.linkURL != nil{
            return
        }
        var url = Device.linkURL
        url.appendPathComponent(self.device.runtime.name)
        let duplicateDeviceNames = self.device.runtime.devices.map{$0.name}.removeDuplicates().1
        if duplicateDeviceNames.contains(self.device.name) {
            url.appendPathComponent("\(self.device.name)_\(self.device.udid)")
        }else{
            url.appendPathComponent(device.name)
        }
        let duplicateAppNames = device.applications.map{$0.bundleDisplayName}.removeDuplicates().1
        if duplicateAppNames.contains(self.bundleDisplayName) {
            url.appendPathComponent("\(self.bundleDisplayName)_\(self.bundleID)")
        }else{
            url.appendPathComponent(self.bundleDisplayName)
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            self.linkURL = url
        } catch {
            return
        }
        let bundleURL = url.appendingPathComponent("Bundle")
        let sandboxURL = url.appendingPathComponent("Sandbox")
        createSymbolicLink(at: bundleURL, withDestinationURL: self.bundleDirUrl)
        createSymbolicLink(at: sandboxURL, withDestinationURL: self.self.sandboxDirUrl)
        /*
         ❌❌
         options:0 or excludeQuickDrawElementsIconCreationOption会造成内存飙升，内存泄漏
         options:exclude10_4ElementsIconCreationOption 无上述问题，但是显示效果不太好
         https://apple.stackexchange.com/questions/6901/how-can-i-change-a-file-or-folder-icon-using-the-terminal
         http://codefromabove.com/2015/03/programmatically-adding-an-icon-to-a-folder-or-file/
         */
        NSWorkspace.shared.setIcon(self.originImage, forFile: url.path, options:[])
    }
    
    /*
     对于Apple Watch模拟器，当调试/安装App的时候，新的APP（可能）安装的时候，会形成一个新的App，App的UDID不同。
     所以新的App和之前App的bundleDirUrl、sandboxDirUrl均不同，但却是同一个App，也就是我们要创建的虚拟文件
     bundleURL、sandboxURL却相同，这时候createSymbolicLink方法会报错（文件已经存在，无法创建），也就是无法更
     新到新的连接。
     so，createSymbolicLink的时候，要做如下判断，并调用FileManager的removeItem方法，先移除，再重新创建link
     */
    private func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) {
        if let destinationUrlPath = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path),
            destinationUrlPath == destURL.path{
            return
        }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createSymbolicLink(at: url, withDestinationURL: destURL)
    }
    
    /*
     如上原因：Apple Watch模拟器调试安装App的时候，新的APP和以前的APP UDID不同，对于代码而言，已经是新的APP，但是虚拟文件
     还是旧的文件。
     因为是新的APP，所以旧的APP会被移除，同时会调用removeLinkDir方法
     所以，调用该方法的时候，做进一步的判断
     */
    func removeLinkDir() {
        guard let url = self.linkURL else {
            return
        }
        let bundleURL = url.appendingPathComponent("Bundle")
        if let destinationUrlPath = try? FileManager.default.destinationOfSymbolicLink(atPath: bundleURL.path),
            FileManager.default.fileExists(atPath: destinationUrlPath){
            return
        }
        try? FileManager.default.removeItem(at: url)
    }
}
