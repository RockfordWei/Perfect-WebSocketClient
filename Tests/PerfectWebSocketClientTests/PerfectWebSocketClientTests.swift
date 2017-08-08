import XCTest
@testable import PerfectWebSocketClient

class PerfectWebSocketClientTests: XCTestCase {
  var websocket = WebSocketClient()

  override func setUp() {
    let r = websocket.connect(url: "http://echo.websocket.org", eventConnected: ({ socket in
      XCTAssertGreaterThan(socket, 0)
      print("OnConnect", socket)
    }),
    eventHeader: ({ header in
      print("OnHeader", header)
      let r = self.websocket.send(data: [0x9, 0])
      XCTAssertGreaterThan(r , 0)
    }),
    eventReceived: ({ bytes in
      XCTAssertGreaterThan(bytes.count, 0)
      print("OnReceive (binary):", bytes)
      var b = bytes
      b.append(0)
      print("OnReceive", String(cString: b))
      self.tearDown()
    }))
    print(r)
  }

  func testExample() {
  }


  static var allTests = [
    ("testExample", testExample),
    ]
}
