import NIOHTTP1
import Foundation

struct RemoveSecretEndpoint: SimpleEndpoint {
	typealias Body = NoBody
	
	typealias Response = NoBody?
	let method: HTTPMethod = .DELETE
	var queryArugments: [URLQueryItem] { [] }

	private let nameOrId: String
	
	init(nameOrId: String) {
		self.nameOrId = nameOrId
	}
	
	var path: String {
		"secrets/\(nameOrId)"
	}
}
