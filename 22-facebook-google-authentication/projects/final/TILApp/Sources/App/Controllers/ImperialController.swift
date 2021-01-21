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

import ImperialGoogle
import Vapor
import Fluent

struct ImperialController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    guard let googleCallbackURL =
            Environment.get("GOOGLE_CALLBACK_URL") else {
      fatalError("Google callback URL not set")
    }
    try routes.oAuth(
      from: Google.self,
      authenticate: "login-google",
      callback: googleCallbackURL,
      scope: ["profile", "email"],
      completion: processGoogleLogin)
  }

  func processGoogleLogin(request: Request, token: String) throws -> EventLoopFuture<ResponseEncodable> {
    return try Google.getUser(on: request).flatMap { userInfo in
      return User.query(on: request.db).filter(\.$username == userInfo.email).first().flatMap { foundUser in
        guard let existingUser = foundUser else {
          let user = User(name: userInfo.name, username: userInfo.email, password: UUID().uuidString)
          return user.save(on: request.db).map {
            request.session.authenticate(user)
            return request.redirect(to: "/")
          }
        }
        request.session.authenticate(existingUser)
        return request.eventLoop.future(request.redirect(to: "/"))
      }
    }
  }
}

struct GoogleUserInfo: Content {
  let email: String
  let name: String
}

extension Google {
  static func getUser(on request: Request) throws -> EventLoopFuture<GoogleUserInfo> {
    var headers = HTTPHeaders()
    headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())

    let googleAPIURL: URI = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
    return request.client.get(googleAPIURL, headers: headers).flatMapThrowing { response in
      guard response.status == .ok else {
        if response.status == .unauthorized {
          throw Abort.redirect(to: "/login-google")
        } else {
          throw Abort(.internalServerError)
        }
      }
      return try response.content.decode(GoogleUserInfo.self)
    }
  }
}
