// https://github.com/daniel-pedersen/SKQueue
// 单个文件夹

import Foundation

public struct SKQueueNotification: OptionSet {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let None             = SKQueueNotification(rawValue: 0)
    public static let Rename           = SKQueueNotification(rawValue: 1 << 0)
    public static let Write            = SKQueueNotification(rawValue: 1 << 1)
    public static let Delete           = SKQueueNotification(rawValue: 1 << 2)
    public static let AttributeChange  = SKQueueNotification(rawValue: 1 << 3)
    public static let SizeIncrease     = SKQueueNotification(rawValue: 1 << 4)
    public static let LinkCountChange  = SKQueueNotification(rawValue: 1 << 5)
    public static let AccessRevocation = SKQueueNotification(rawValue: 1 << 6)
    public static let Default          = SKQueueNotification(rawValue: 0x7F)
 
    public func toStrings() -> [String] {
        var s = [String]()
        if contains(.None)           { s.append("None") }
        if contains(.Rename)           { s.append("Rename") }
        if contains(.Write)            { s.append("Write") }
        if contains(.Delete)           { s.append("Delete") }
        if contains(.AttributeChange)  { s.append("AttributeChange") }
        if contains(.SizeIncrease)     { s.append("SizeIncrease") }
        if contains(.LinkCountChange)  { s.append("LinkCountChange") }
        if contains(.AccessRevocation) { s.append("AccessRevocation") }
        if contains(.Default)           { s.append("Default") }
        return s
    }
}

class SKQueuePath {
    var path: String
    var fileDescriptor: Int32
    var notification: SKQueueNotification
    
    init?(_ path: String, notification: SKQueueNotification) {
        self.path = path
        self.fileDescriptor = open((path as NSString).fileSystemRepresentation, O_EVTONLY, 0)
        self.notification = notification
        if self.fileDescriptor < 0 {
            return nil
        }
    }
    
    deinit {
        if self.fileDescriptor >= 0 {
            close(self.fileDescriptor)
        }
    }
}

public class SKQueue {
    private var kqueueId: Int32
    private var watchedPaths = [String: SKQueuePath]()
    private var keepWatcherThreadRunning = false
    public typealias CallClosure = (_ notification: SKQueueNotification, _ path: String) -> Void
    private var callback:CallClosure
    
    public init?(_ callback: @escaping CallClosure) {
        kqueueId = kqueue()
        if (kqueueId == -1) {
            return nil
        }
        self.callback = callback
    }
    
    deinit {
        keepWatcherThreadRunning = false
        removeAllPaths()
    }
    
    
    public func addPath(_ path: String, notifyingAbout notification: SKQueueNotification = SKQueueNotification.Default) {
        if addPathToQueue(path, notifyingAbout: notification) == nil {
            NSLog("SKQueue tried to add the path \(path) to watchedPaths, but the SKQueuePath was nil. \nIt's possible that the host process has hit its max open file descriptors limit.")
        }
    }
    
    public func isPathWatched(_ path: String) -> Bool {
        return watchedPaths[path] != nil
    }
    
    public func removePath(_ path: String) {
        if let pathEntry = watchedPaths.removeValue(forKey: path) {
            Unmanaged<SKQueuePath>.passUnretained(pathEntry).release()
        }
    }
    
    public func removeAllPaths() {
        watchedPaths.keys.forEach(removePath)
    }
    
    public func numberOfWatchedPaths() -> Int {
        return watchedPaths.count
    }
    
    public func fileDescriptorForPath(_ path: String) -> Int32 {
        guard watchedPaths[path] != nil else {
            return -1
        }
        
        return fcntl(watchedPaths[path]!.fileDescriptor, F_DUPFD)
    }
    
    private func addPathToQueue(_ path: String, notifyingAbout notification: SKQueueNotification) -> SKQueuePath? {
        var pathEntry = watchedPaths[path]
        
        if pathEntry != nil {
            if pathEntry!.notification.contains(notification) {
                return pathEntry
            }
            pathEntry!.notification.insert(notification)
        } else {
            pathEntry = SKQueuePath(path, notification: notification)
            if pathEntry == nil {
                return nil
            }
            watchedPaths[path] = pathEntry!
        }
        
        var nullts = timespec(tv_sec: 0, tv_nsec: 0)
        var ev = ev_create(
            ident: UInt(pathEntry!.fileDescriptor),
            filter: Int16(EVFILT_VNODE),
            flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
            fflags: notification.rawValue,
            data: 0,
            udata: UnsafeMutableRawPointer(Unmanaged<SKQueuePath>.passRetained(watchedPaths[path]!).toOpaque())
        )
        
        kevent(kqueueId, &ev, 1, nil, 0, &nullts)
        
        if !keepWatcherThreadRunning {
            keepWatcherThreadRunning = true
            DispatchQueue.global().async(execute: watcherThread)
        }
        
        return pathEntry
    }
    
    private func watcherThread() {
        var ev = kevent(), timeout = timespec(tv_sec: 20, tv_nsec: 0), fd = kqueueId
        
        while (keepWatcherThreadRunning) {
            let n = kevent(fd, nil, 0, &ev, 1, &timeout)
            if n > 0 && ev.filter == Int16(EVFILT_VNODE) && ev.fflags != 0 {
                let pathEntry = Unmanaged<SKQueuePath>.fromOpaque(ev.udata).takeUnretainedValue()
                let notification = SKQueueNotification(rawValue: ev.fflags)
                self.callback(notification, pathEntry.path)
            }
        }
        
        if close(fd) == -1 {
            NSLog("SKQueue watcherThread: Couldn't close main kqueue (%d)", errno)
        }
    }
}

private func ev_create(ident: UInt, filter: Int16, flags: UInt16, fflags: UInt32, data: Int, udata: UnsafeMutableRawPointer) -> kevent {
    var ev = kevent()
    ev.ident = ident
    ev.filter = filter
    ev.flags = flags
    ev.fflags = fflags
    ev.data = data
    ev.udata = udata
    return ev
}
