import NIOHTTP1
import Foundation

struct PingEndpoint: SimpleEndpoint {
	typealias Body = NoBody
	typealias Response = String
	var queryArugments: [URLQueryItem] { [] }

	var method: HTTPMethod = .GET
	let path: String = "_ping"
}
