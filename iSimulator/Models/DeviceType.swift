//
//  DeviceTypes.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation

struct DeviceType: Decodable {
    let name: String
    let identifier: String
    
    enum CodingKeys: CodingKey {
        case name
        case identifier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        identifier = try container.decode(String.self, forKey: .identifier)
    }
    
    var dataReportDic: [String: String] {
        return ["n": name, "id": identifier]
    }
}
