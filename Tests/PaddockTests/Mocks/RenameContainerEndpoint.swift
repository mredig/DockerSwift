@testable import Paddock
import Foundation
import NIO
import AsyncHTTPClient

extension RenameContainerEndpoint: MockedResponseEndpoint {
	public var responseData: [MockedResponseData] {
		[.rawData(ByteBuffer())]
	}

	public func validate(request: HTTPClientRequest) throws {
		guard request.method == .POST else { throw DockerGeneralError.message("require post method") }
		guard
			let url = URL(string: request.url)
		else { throw DockerGeneralError.message("invalid url") }

		let components = url.pathComponents

		guard
			let containerIndex = components.firstIndex(of: "containers"),
			(components.startIndex..<components.endIndex).contains(containerIndex + 2),
			components[containerIndex + 2] == "rename"
		else { throw DockerGeneralError.message("invalid path for rename: \(url)") }

		let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
		guard
			queryItems.contains(where: { $0.name == "name" })
		else { throw DockerGeneralError.message("Missing rename value") }
	}
}
