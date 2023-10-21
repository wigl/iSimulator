//
//  Runtime.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation

enum Availability: Decodable {
    case available, unavailable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "(available)":
            self = .available
        case "(unavailable, runtime profile not found)", "(unavailable)":
            self = .unavailable
        default:
            throw DecodingError.valueNotFound(String.self, .init(codingPath: decoder.codingPath, debugDescription: "Unknown Availability type \(rawValue)"))
        }
    }
}

final class Runtime: Decodable {
    
    enum OSType: String {
        case iOS, tvOS, watchOS, None
    }
    
    let buildversion: String
    let availability: Availability
    let name: String
    let identifier: String
    let version: String
    var devices: [Device]
    var devicetypes: [DeviceType]
    
    var osType: OSType{
        if name.contains("iOS") {
            return .iOS
        } else if name.contains("tvOS") {
            return .tvOS
        } else if name.contains("watchOS") {
            return .watchOS
        } else{
            return .None
        }
    }
    
    enum CodingKeys: CodingKey {
        case buildversion
        case availability
        case name
        case identifier
        case version
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buildversion = try container.decode(String.self, forKey: .buildversion)
        availability = try container.decodeIfPresent(Availability.self, forKey: .availability) ?? .unavailable
        name = try container.decode(String.self, forKey: .name)
        identifier = try container.decode(String.self, forKey: .identifier)
        version = try container.decode(String.self, forKey: .version)
        devices = []
        devicetypes = []
    }
    
    var dataReportDic: [String: String] {
        return ["n": name, "b": buildversion, "v": version, "id": identifier]
    }
}
