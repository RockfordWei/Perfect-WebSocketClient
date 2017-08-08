import cURL

public class WebSocketClient {

  public typealias EventConnection = (Int) -> Void
  public typealias EventIncoming = ([Int8]) -> Void
  public typealias EventHeader = (String) -> Void

  static var sInit:Int = {
    curl_global_init(Int(CURL_GLOBAL_SSL | CURL_GLOBAL_WIN32))
    return 1
  }()

  private var handle: UnsafeMutableRawPointer? = nil
  private var header_list_ptr: UnsafeMutablePointer<curl_slist>? = nil

  private var _sockfd = 0

  public var onConnect: EventConnection = { _ in }
  public var onReceive: EventIncoming = { _ in }
  public var onHeader: EventHeader = { _ in }

  public var reserved = 0

  public var sockfd: Int {
    get {
      return _sockfd
    }
    set {
      _sockfd = newValue
      self.onConnect(newValue)
    }
  }

  public func send(data: [Int8]) -> Int {
    if _sockfd > 0 {
      return data.withUnsafeBufferPointer { buffered -> Int in
        if let b = buffered.baseAddress, data.count > 0 {
          return write(Int32(_sockfd), b, data.count)
        } else {
          return 0
        }
      }
    } else {
      return 0
    }
  }

  public func send(msg: String) -> Int {
    if _sockfd > 0 {
      return msg.withCString { pointer -> Int in
        if msg.utf8.count > 0 {
          return write(Int32(_sockfd), pointer, msg.utf8.count)
        } else {
          return 0
        }
      }
    } else {
      return 0
    }
  }

  public init() {
    handle = curl_easy_init()

    header_list_ptr = curl_slist_append(nil , "HTTP/1.1 101 WebSocket Protocol Handshake")
    header_list_ptr = curl_slist_append(header_list_ptr , "Upgrade: WebSocket")
    header_list_ptr = curl_slist_append(header_list_ptr , "Connection: Upgrade")
    header_list_ptr = curl_slist_append(header_list_ptr , "Sec-WebSocket-Version: 13")
    header_list_ptr = curl_slist_append(header_list_ptr , "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==")
  }

  public func connect (url: String,
               eventConnected: EventConnection? = nil,
               eventHeader: EventHeader? = nil,
               eventReceived: EventIncoming? = nil) -> CURLcode {

    if let on_connect = eventConnected {
      onConnect = on_connect
    }

    if let on_receive = eventReceived {
      onReceive = on_receive
    }

    if let on_header = eventHeader {
      onHeader = on_header
    }

    _ = curl_easy_setopt_cstr(handle, CURLOPT_URL, url);
    _ = curl_easy_setopt_slist(handle, CURLOPT_HTTPHEADER, header_list_ptr)

    self.reserved = 100
    let this = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    _ = curl_easy_setopt_void(handle, CURLOPT_OPENSOCKETDATA, this)
    _ = curl_easy_setopt_void(handle, CURLOPT_HEADERDATA, this)
    _ = curl_easy_setopt_void(handle, CURLOPT_WRITEDATA, this)
    _ = curl_easy_setopt_void(handle, CURLOPT_READDATA, this)
    let openFunc: curl_func = { (p, purpose, address, clientp )  in
      guard let point = p, let addr = UnsafeRawPointer(bitPattern: address)
        else { return -1 }
      let q = Unmanaged<WebSocketClient>.fromOpaque(point)
      let me = q.takeUnretainedValue()
      let sock_addr = addr.assumingMemoryBound(to: curl_sockaddr.self)
      let sa = sock_addr.pointee
      let sock = socket(sa.family, sa.socktype, sa.protocol)
      if sock > 0 {
        me.sockfd = Int(sock)
      } else {
        me.sockfd = -1
      }
      return me.sockfd
    }
    _ = curl_easy_setopt_func(handle, CURLOPT_OPENSOCKETFUNCTION, openFunc)

    let headerReadFunc: curl_func = {
      (a, size, num, p) -> Int in

      let me = Unmanaged<WebSocketClient>.fromOpaque(p!).takeUnretainedValue()
      if let bytes = a?.assumingMemoryBound(to: Int8.self) {
        let fullCount = size*num
        let s = String(cString: bytes)
        me.onHeader(s)
        return fullCount
      }
      return 0
    }
    _ = curl_easy_setopt_func(handle, CURLOPT_HEADERFUNCTION, headerReadFunc)

    let writeFunc: curl_func = {
      (a, size, num, p) -> Int in

      let me = Unmanaged<WebSocketClient>.fromOpaque(p!).takeUnretainedValue()
      if let bytes = a?.assumingMemoryBound(to: Int8.self) {
        let fullCount = size*num
        let array = UnsafeBufferPointer(start: bytes, count: fullCount)
        me.onReceive(Array(array))
        return fullCount
      }
      return 0
    }
    _ = curl_easy_setopt_func(handle, CURLOPT_WRITEFUNCTION, writeFunc)
    return curl_easy_perform(handle)
  }

  deinit {
    curl_easy_cleanup(handle)
  }
}
