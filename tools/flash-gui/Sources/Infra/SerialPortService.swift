import Darwin
import Foundation
import IOKit
import IOKit.serial

final class SerialPortService {
    private let readQueue = DispatchQueue(label: "flashgui.serial.read")
    private var readSource: DispatchSourceRead?
    private var fd: Int32 = -1

    private var onData: ((String) -> Void)?
    private var onDisconnect: ((String) -> Void)?
    private var onError: ((String) -> Void)?

    func listPorts() -> [SerialPortInfo] {
        guard let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary? else {
            return []
        }

        matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var ports: [SerialPortInfo] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let callout = copyStringProperty(service: service, key: kIOCalloutDeviceKey)
            let ttyName = copyStringProperty(service: service, key: kIOTTYDeviceKey)
            IOObjectRelease(service)

            if let callout {
                ports.append(SerialPortInfo(path: callout, name: ttyName ?? "串口设备"))
            }
            service = IOIteratorNext(iterator)
        }

        return ports.sorted { lhs, rhs in lhs.path < rhs.path }
    }

    func open(
        path: String,
        baudRate: Int,
        onData: @escaping (String) -> Void,
        onDisconnect: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) -> Bool {
        close()

        let descriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        if descriptor == -1 {
            onError("打开 \(path) 失败：\(String(cString: strerror(errno)))")
            return false
        }

        guard configurePort(fd: descriptor, baudRate: baudRate, onError: onError) else {
            Darwin.close(descriptor)
            return false
        }

        self.fd = descriptor
        self.onData = onData
        self.onDisconnect = onDisconnect
        self.onError = onError

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: readQueue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
        }
        source.setCancelHandler {}
        readSource = source
        source.resume()

        return true
    }

    func close() {
        if let source = readSource {
            source.cancel()
            readSource = nil
        }

        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    func sendLine(_ line: String) -> Bool {
        guard fd >= 0 else {
            onError?("串口尚未打开。")
            return false
        }

        let text = line.hasSuffix("\n") ? line : line + "\n"
        guard let data = text.data(using: .utf8) else {
            onError?("文本编码为 UTF-8 失败。")
            return false
        }

        let ok = data.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            var totalWritten = 0
            while totalWritten < data.count {
                let pointer = baseAddress.advanced(by: totalWritten)
                let writeResult = Darwin.write(fd, pointer, data.count - totalWritten)
                if writeResult < 0 {
                    if errno == EINTR {
                        continue
                    }
                    return false
                }
                totalWritten += writeResult
            }
            return true
        }

        if !ok {
            onError?("写入失败：\(String(cString: strerror(errno)))")
        }
        return ok
    }

    private func handleReadable() {
        guard fd >= 0 else {
            return
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let readCount = Darwin.read(fd, &buffer, buffer.count)
        if readCount > 0 {
            let text = String(decoding: buffer.prefix(readCount), as: UTF8.self)
            onData?(text)
            return
        }

        if readCount == 0 {
            onDisconnect?("串口设备已断开。")
            close()
            return
        }

        if errno == EAGAIN || errno == EINTR {
            return
        }

        onDisconnect?("串口读取失败：\(String(cString: strerror(errno)))")
        close()
    }

    private func configurePort(fd: Int32, baudRate: Int, onError: @escaping (String) -> Void) -> Bool {
        if fcntl(fd, F_SETFL, 0) == -1 {
            onError("设置阻塞模式失败：\(String(cString: strerror(errno)))")
            return false
        }

        var options = termios()
        if tcgetattr(fd, &options) != 0 {
            onError("读取串口参数失败：\(String(cString: strerror(errno)))")
            return false
        }

        cfmakeraw(&options)
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)

        let speed = serialSpeed(for: baudRate)
        if cfsetispeed(&options, speed) != 0 || cfsetospeed(&options, speed) != 0 {
            onError("设置波特率 \(baudRate) 失败：\(String(cString: strerror(errno)))")
            return false
        }

        if tcsetattr(fd, TCSANOW, &options) != 0 {
            onError("应用串口参数失败：\(String(cString: strerror(errno)))")
            return false
        }

        return true
    }

    private func serialSpeed(for baudRate: Int) -> speed_t {
        switch baudRate {
        case 9600:
            return speed_t(B9600)
        case 19200:
            return speed_t(B19200)
        case 38400:
            return speed_t(B38400)
        case 57600:
            return speed_t(B57600)
        case 115200:
            return speed_t(B115200)
        case 230400:
            return speed_t(B230400)
        default:
            return speed_t(baudRate)
        }
    }

    private func copyStringProperty(service: io_object_t, key: String) -> String? {
        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else {
            return nil
        }
        return property as? String
    }
}
