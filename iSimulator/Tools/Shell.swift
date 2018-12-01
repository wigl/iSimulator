//
//  Shell.swift
//  iSimulator
//
//  Created by 靳朋 on 2017/8/23.
//  Copyright © 2017年 niels.jin. All rights reserved.
//

import Foundation

@discardableResult
func shell(_ launchPath: String, arguments: String...) -> (outStr: String, err: String) {
    let process = Process()
    process.launchPath = launchPath
    process.arguments = arguments
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.launch()
    
    
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let outputStr = String(data: outputData, encoding: String.Encoding.utf8)
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorStr = String(data: errorData, encoding: String.Encoding.utf8)
    
    return (outputStr ?? "", errorStr ?? "")
}
