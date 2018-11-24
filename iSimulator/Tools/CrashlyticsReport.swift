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
    
    var currentSimctlListJsonStr = "" {
        didSet {
            Crashlytics.sharedInstance().setObjectValue(currentSimctlListJsonStr, forKey: currentSimctlListJsonStrKey)
        }
    }
    
    private init() {
        
    }
    
    private func reportUserInfo() -> [String : Any] {
        return [currentSimctlListJsonStrKey: currentSimctlListJsonStr]
    }
    
    func runtimeNilReport() {
        Crashlytics.sharedInstance().recordError(ReportError.runtimeNil, withAdditionalUserInfo: self.reportUserInfo())
    }
    
}

enum ReportError: CustomNSError {
    
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
