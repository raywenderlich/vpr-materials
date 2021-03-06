/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Vapor

extension String: Error {}

public func sockets(_ app: Application) {
  app.webSocket("echo") { req, ws in
    print("ws connected")
    ws.onText { ws, text in
      print("ws received: \(text)")
      ws.send("echo: " + text)
    }
  }
  
  /// only one path, for a singular session per server
  app.webSocket("session") { req, ws in
    let color: ColorComponents
    let position: RelativePoint
    do {
      color = try req.query.decode(ColorComponents.self)
      position = try req.query.decode(RelativePoint.self)
    } catch {
      _ = ws.close(code: .unacceptableData)
      return
    }
    print("new user joined with: \(color) at \(position)")
    
    let newId = UUID().uuidString
    TouchSessionManager.default.insert(id: newId, color: color, at: position, on: ws)
    
    ws.onText { ws, text in
      do {
        let pt = try JSONDecoder().decode(
          RelativePoint.self,
          from: Data(text.utf8)
        )
        TouchSessionManager.default.update(id: newId, to: pt)
      } catch {
        ws.send("unsupported update: \(text)")
      }
    }
    
    _ = ws.onClose.always { result in
      TouchSessionManager.default.remove(id: newId)
    }
  }
}
