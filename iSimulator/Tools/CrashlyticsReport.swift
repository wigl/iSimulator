//
//  CrashlyticsReport.swift
//  iSimulator
//
//  Created by Peng Jin 靳朋 on 2018/11/24.
//  Copyright © 2018 niels.jin. All rights reserved.
//

import Foundation
import Crashlytics

private let currentSimctlListJsonStrKey = "simctlList"

class LogReport {
    
    static let `default` = LogReport()
    
    private init() {
        
    }
    
    @available(*, deprecated)
    func runtimeNilReport() {
        Crashlytics.sharedInstance().recordError(ReportError.runtimeNil, withAdditionalUserInfo: nil)
    }
    
    func logSimctlList() {
        #if DEBUG
        
        #else
            let dic = TotalModel.default.dataReportDic
            do {
                let data = try JSONSerialization.data(withJSONObject: dic, options: [])
                if let str = String.init(data: data, encoding: .utf8) {
                    CLSLogv("%@", getVaList([str]))
                }
            } catch {

            }
        #endif
    }
    
}

enum ReportError: CustomNSError {
    
    @available(*, deprecated)
    case runtimeNil
    
    static var errorDomain: String {
        return "niels.jin.iSimulator.ReportError"
    }
    
    var errorCode: Int {
        switch self {
        case .runtimeNil:
            return -10001
        }
    }
}
