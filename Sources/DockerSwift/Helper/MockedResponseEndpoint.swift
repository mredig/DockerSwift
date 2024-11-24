import NIO
import Foundation
import NIOHTTP1
import AsyncHTTPClient

protocol MockedResponseEndpoint: Endpoint {
	var responseData: [MockedResponseData] { get }

	func mockedResponse(_ request: HTTPClientRequest) async throws -> ByteBuffer
	func mockedStreamingResponse(_ request: HTTPClientRequest) async throws -> AsyncThrowingStream<ByteBuffer, Error>
}

extension MockedResponseEndpoint {
	static var podmanHeaders: HTTPHeaders {
		[
			"Api-Version": "1.41",
			"Server": "Libpod/5.2.3 (linux)",
			"Libpod-Api-Version": "5.2.3",
		]
	}

	static var dockerHeaders: HTTPHeaders {
		[
			"Api-Version": "1.47",
			"Server": "Docker/27.3.1 (linux)",
			"Docker-Experimental": "false",
			"Ostype": "linux",
		]
	}

	func mockedResponse(_ request: HTTPClientRequest) async throws -> ByteBuffer {
		guard
			let first = responseData.first
		else { throw DockerError.message("Error retrieving mock data") }

		try await Task.sleep(for: .milliseconds(5))
		return first.data
	}

	func mockedStreamingResponse(_ request: HTTPClientRequest) async throws -> AsyncThrowingStream<ByteBuffer, Error> {
		guard responseData.isEmpty == false else { throw DockerError.message("No mocked data available") }

		let (stream, continuation) = AsyncThrowingStream<ByteBuffer, Error>.makeStream()

		Task {
			for data in responseData {
				continuation.yield(data.data)
				try await Task.sleep(for: .milliseconds(20))
			}
			
			continuation.finish()
		}

		return stream
	}
}

enum MockedResponseData {
	case rawData(ByteBuffer)
	case string(String)
	case base64EncodedString(String)

	var data: ByteBuffer {
		switch self {
		case .rawData(let data):
			data
		case .string(let string):
			ByteBuffer(string: string)
		case .base64EncodedString(let b64):
			ByteBuffer(data: Data(base64Encoded: b64) ?? Data())
		}
	}
}

