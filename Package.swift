// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "PerfectWebSocketClient",
    dependencies: [
  		.Package(url: "https://github.com/PerfectlySoft/Perfect-libcurl.git", majorVersion: 2)
  	]
)
