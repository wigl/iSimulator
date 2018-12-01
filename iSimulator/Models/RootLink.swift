//
//  RootLink.swift
//  iSimulator
//
//  Created by Peng Jin 靳朋 on 2018/12/1.
//  Copyright © 2018 niels.jin. All rights reserved.
//

import Foundation

private let kUserDefaultDocumentKey = "kUserDefaultDocumentKey"
private let kDocumentName = "iSimulator"

class RootLink {
    
    static let queue = DispatchQueue(label: "iSimulator.update.queue")
    
    static func update(with path: String, finish:@escaping (_ error: String?)->Void) {
        guard FileManager.default.fileExists(atPath: path) else {
            finish("Folder doesn't exist!")
            return
        }
        let linkURL = URL(fileURLWithPath: path).appendingPathComponent(kDocumentName)
        self.queue.async {
            do {
                try FileManager.default.moveItem(at: self.url, to: linkURL)
                self.url = linkURL
                UserDefaults.standard.set(path, forKey: kUserDefaultDocumentKey)
                UserDefaults.standard.synchronize()
                finish(nil)
            } catch {
                finish(error.localizedDescription)
            }
        }
    }
    
    static private(set) var url: URL = {
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
