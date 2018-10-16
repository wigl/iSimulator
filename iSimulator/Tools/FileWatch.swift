// https://github.com/soh335/FileWatch
// 包含子文件，所有都列出来

import Foundation

public class FileWatch {
    
    // wrap FSEventStreamEventFlags as  OptionSetType
    public struct EventFlag: OptionSet {
        public let rawValue: FSEventStreamEventFlags
        public init(rawValue: FSEventStreamEventFlags) {
            self.rawValue = rawValue
        }
        
        public static let None = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagNone))
        
        public static let MustScanSubDirs = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs))
        public static let UserDropped = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped))
        public static let KernelDropped = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped))
        public static let EventIdsWrapped = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped))
        public static let HistoryDone = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone))
        public static let RootChanged = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged))
        public static let Mount = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagMount))
        public static let Unmount = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount))
        
        @available(OSX 10.7, *)
        public static let ItemCreated = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated))
        
        @available(OSX 10.7, *)
        public static let ItemRemoved = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved))
        
        @available(OSX 10.7, *)
        public static let ItemInodeMetaMod = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod))
        
        @available(OSX 10.7, *)
        public static let ItemRenamed = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed))
        
        @available(OSX 10.7, *)
        public static let ItemModified = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified))
        
        @available(OSX 10.7, *)
        public static let ItemFinderInfoMod = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod))
        
        @available(OSX 10.7, *)
        public static let ItemChangeOwner = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner))
        
        @available(OSX 10.7, *)
        public static let ItemXattrMod = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod))
        
        @available(OSX 10.7, *)
        public static let ItemIsFile = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile))
        
        @available(OSX 10.7, *)
        public static let ItemIsDir = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir))
        
        @available(OSX 10.7, *)
        public static let ItemIsSymlink = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink))
        
        @available(OSX 10.9, *)
        public static let OwnEvent = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent))
        
        @available(OSX 10.10, *)
        public static let ItemIsHardlink = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsHardlink))
        
        @available(OSX 10.10, *)
        public static let ItemIsLastHardlink = EventFlag(rawValue: FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsLastHardlink))
    }
    
    // wrap FSEventStreamCreateFlags as OptionSetType
    public struct CreateFlag: OptionSet {
        public let rawValue: FSEventStreamCreateFlags
        public init(rawValue: FSEventStreamCreateFlags) {
            self.rawValue = rawValue
        }
        
        public static let None = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
        public static let UseCFTypes = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes))
        public static let NoDefer = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer))
        public static let WatchRoot = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot))
        
        @available(OSX 10.6, *)
        public static let IgnoreSelf = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf))
        
        @available(OSX 10.7, *)
        public static let FileEvents = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents))
        
        @available(OSX 10.9, *)
        public static let MarkSelf = CreateFlag(rawValue: FSEventStreamCreateFlags(kFSEventStreamCreateFlagMarkSelf))
    }
    
    public struct Event {
        public let path: String
        public let flag:  EventFlag
        public let eventID: FSEventStreamEventId
    }
    
    public enum Error: Swift.Error {
        case startFailed
        case streamCreateFailed
        case notContainUseCFTypes
    }
    
    public typealias EventHandler = (Event) -> Void
    
    public let eventHandler: EventHandler
    private var eventStream: FSEventStreamRef?
    
    public init(paths: [String], createFlag: CreateFlag, runLoop: RunLoop, latency: CFTimeInterval, eventHandler: @escaping EventHandler) throws {
        self.eventHandler = eventHandler
        
        var ctx = FSEventStreamContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        
        if !createFlag.contains(.UseCFTypes) {
            throw Error.notContainUseCFTypes
        }
        
        guard let eventStream = FSEventStreamCreate(kCFAllocatorDefault, FileWatch.StreamCallback, &ctx, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, createFlag.rawValue) else {
            throw Error.streamCreateFailed
        }
        
        FSEventStreamScheduleWithRunLoop(eventStream, runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        if !FSEventStreamStart(eventStream) {
            throw Error.startFailed
        }
        
        self.eventStream = eventStream
    }
    
    deinit {
        guard let eventStream = self.eventStream else {
            return
        }
        FSEventStreamStop(eventStream)
        FSEventStreamInvalidate(eventStream)
        FSEventStreamRelease(eventStream)
        self.eventStream = nil

    }
    
    // http://stackoverflow.com/questions/33260808/swift-proper-use-of-cfnotificationcenteraddobserver-w-callback
    private static let StreamCallback: FSEventStreamCallback = {(streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) -> Void in
        
        let `self` = unsafeBitCast(clientCallBackInfo, to: FileWatch.self)
        guard let eventPathArray = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else {
            return
        }
        var eventFlagArray = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
        var eventIdArray   = Array(UnsafeBufferPointer(start: eventIds, count: numEvents))
        
        for i in 0..<numEvents {
            let path = eventPathArray[i]
            let flag = eventFlagArray[i]
            let eventID = eventIdArray[i]
            let event = Event(path: path, flag: EventFlag(rawValue: flag), eventID: eventID)
            self.eventHandler(event)
        }
    }
}
