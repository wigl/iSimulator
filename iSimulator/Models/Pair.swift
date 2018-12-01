//
//  Pair.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/11/15.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import ObjectMapper

class Pair: Mappable {
    
    var watch: Device?
    var phone: Device?
    var state = ""
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        watch <- map["watch"]
        phone <- map["phone"]
        state <- map["state"]
    }
    
    var dataReportDic: [String: String] {
        if watch == nil, phone == nil {
            return [:]
        } else {
            return ["w": watch?.udid ?? "", "p": phone?.udid ?? ""]
        }
    }
    
}
