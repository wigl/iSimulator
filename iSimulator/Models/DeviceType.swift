//
//  DeviceTypes.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import ObjectMapper

class DeviceType: Mappable {
    var name = ""
    var identifier = ""
    
    required init?(map: Map) { }
    
    func mapping(map: Map) {
        name <- map["name"]
        identifier <- map["identifier"]
    }
}
