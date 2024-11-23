import Foundation
import NIOHTTP1

struct CommitContainerEndpoint: SimpleEndpoint {
	typealias Response = CommitContainerResponse
	typealias Body = ContainerConfig?
	var method: HTTPMethod = .POST
	var queryArugments: [URLQueryItem] {
		[
			URLQueryItem(name: "container", value: nameOrId),
			repo.map { URLQueryItem(name: "repo", value: $0.description) },
			tag.map { URLQueryItem(name: "tag", value: $0) },
			comment.map { URLQueryItem(name: "comment", value: $0) },
			URLQueryItem(name: "pause", value: pause.description),
		]
			.compactMap(\.self)
	}

	var path: String {
		"commit"
	}
	var body: ContainerConfig?
	
	private let nameOrId: String
	private let pause: Bool
	private let repo: String?
	private let tag: String?
	private let comment: String?

	init(nameOrId: String, spec: ContainerConfig?, pause: Bool, repo: String?, tag: String?, comment: String?) {
		self.nameOrId = nameOrId
		self.body = spec
		self.pause = pause
		self.repo = repo
		self.tag = tag
		self.comment = comment
	}
	
	struct CommitContainerResponse: Codable {
		let Id: String
	}
}
