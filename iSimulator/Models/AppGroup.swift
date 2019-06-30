//
//  AppGroup.swift
//  iSimulator
//
//  Created by Peng Jin 靳朋 on 2019/6/30.
//  Copyright © 2019 niels.jin. All rights reserved.
//

import Foundation

class AppGroup: Hashable {
    let fileURL: URL
    let id: String
    
    private(set) var linkURL:URL?
    
    init(fileURL: URL, id: String) {
        self.fileURL = fileURL
        self.id = id
        self.linkURL = nil
    }
    
    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        return lhs.fileURL == rhs.fileURL && lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(fileURL)
    }
    
}

extension AppGroup {
    
    func createLinkDir(device: Device) {
        guard self.linkURL == nil else {
            return
        }
        var url = RootLink.url
        url.appendPathComponent(device.runtime.name)
        let duplicateDeviceNames = device.runtime.devices.map{$0.name}.divideDuplicates().duplicates
        if duplicateDeviceNames.contains(device.name) {
            url.appendPathComponent("\(device.name)_\(device.udid)")
        }else{
            url.appendPathComponent(device.name)
        }
        url.appendPathComponent("AppGroupSandBox")
        url.appendPathComponent(self.id)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            self.linkURL = url
        } catch {
            return
        }
        createSymbolicLink(at: url, withDestinationURL: fileURL)
    }
    
    private func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) {
        if let destinationUrlPath = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path),
            destinationUrlPath == destURL.path{
            return
        }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createSymbolicLink(at: url, withDestinationURL: destURL)
    }
    
}
