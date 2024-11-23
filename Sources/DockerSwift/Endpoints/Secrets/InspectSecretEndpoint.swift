import Foundation
import NIOHTTP1

struct InspectSecretEndpoint: SimpleEndpoint {
	typealias Body = NoBody
	typealias Response = Secret
	var method: HTTPMethod = .GET
	var queryArugments: [URLQueryItem] { [] }

	private let nameOrId: String
	
	init(nameOrId: String) {
		self.nameOrId = nameOrId
	}
	
	var path: String {
		"secrets/\(nameOrId)"
	}
}
