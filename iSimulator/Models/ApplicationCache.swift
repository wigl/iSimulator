//
//  ApplicationCache.swift
//  iSimulator
//
//  Created by Peng Jin 靳朋 on 2018/12/1.
//  Copyright © 2018 niels.jin. All rights reserved.
//

import Foundation

class ApplicationCache {

    var urlAndAppDic: [URL: Application] = [:]
    
    var sandboxURLs: Set<URL> = []
    
    /// 需要忽略的 boundleURL/sandboxURL：如无效的文件夹
    var ignoreURLs: Set<URL> = []
    
    init() {
        
    }
}

class AppGroupCache {
    var groups: Set<AppGroup> = []
}
