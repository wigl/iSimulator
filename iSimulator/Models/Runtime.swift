//
//  Runtime.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation
import ObjectMapper

enum Availability: String {
    case available = "(available)"
    case unavailable = "(unavailable, runtime profile not found)"
}

class Runtime: Mappable {
    
    enum OSType: String {
        case iOS, tvOS, watchOS, None
    }
    
    var buildversion = ""
    var availability = Availability.unavailable
    var name = ""
    var identifier = ""
    var version = ""
    var devices: [Device] = []
    var devicetypes: [DeviceType] = []
    var osType: OSType{
        if name.contains("iOS"){
            return .iOS
        }else if name.contains("tvOS"){
            return .tvOS
        }else if name.contains("watchOS"){
            return .watchOS
        }else{
            return .None
        }
    }
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        buildversion <- map["buildversion"]
        availability <- (map["availability"], EnumTransform())
        name <- map["name"]
        identifier <- map["identifier"]
        version <- map["version"]
    }
    
    var dataReportDic: [String: String] {
        return ["n": name, "b": buildversion, "v": version, "id": identifier]
    }
}
