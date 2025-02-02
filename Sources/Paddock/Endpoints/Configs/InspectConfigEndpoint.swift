import Foundation
import NIOHTTP1

struct InspectConfigEndpoint: SimpleEndpoint {
	typealias Body = NoBody
	typealias Response = Config
	let method: HTTPMethod = .GET
	var queryArugments: [URLQueryItem] { [] }

	private let nameOrId: String
	
	init(nameOrId: String) {
		self.nameOrId = nameOrId
	}
	
	var path: String {
		"configs/\(nameOrId)"
	}
}
