import AsyncHTTPClient
@testable import DockerSwift

extension DisconnectContainerEndpoint: MockedResponseEndpoint {
	public var responseData: [MockedResponseData] {[.string("OK")]}

	public func validate(request: HTTPClientRequest) throws {
		let url = try validate(method: .POST, andGetURLFromRequest: request)

		guard
			let disconnectIndex = url.pathComponents.lastIndex(of: "disconnect"),
			disconnectIndex >= 2,
			url.pathComponents[disconnectIndex - 2] == "networks"
		else { throw DockerError.message("Invalid path") }
	}
}
