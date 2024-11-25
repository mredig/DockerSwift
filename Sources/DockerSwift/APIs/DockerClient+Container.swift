import Foundation
import NIO
import AsyncHTTPClient

extension DockerClient {
	
	/// APIs related to containers.
	public var containers: ContainersAPI {
		.init(client: self)
	}
	
	public struct ContainersAPI {
		fileprivate var client: DockerClient
		
		/// Fetches all containers in the Docker system.
		/// - Parameter all: If `true` all containers are fetched, otherwise only running containers.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns a list of `Container`.
		public func list(all: Bool = false) async throws -> [ContainerSummary] {
			return try await client.run(ListContainersEndpoint(all: all))
		}
		
		/// Fetches the latest information about a container by a given name or id..
		/// - Parameter nameOrId: Name or id of a container.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns the `Container` and its information.
		public func get(_ nameOrId: String) async throws -> Container {
			try await client.run(InspectContainerEndpoint(nameOrId: nameOrId, logger: client.logger))
		}

		/// Creates a new container from a given image. If specified the commands override the default commands from the image.
		/// - Parameters:
		///   - imageID: ID of an `Image`.
		///   - commands: Override the default commands from the image. Default `nil`.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns  the created `Container`'s ID.
		public func create(imageID: String, commands: [String]? = nil) async throws -> CreateContainerEndpoint.Response {
			try await create(name: nil, spec: ContainerConfig(image: imageID, command: commands))
		}

		/// Creates a new container from a fully customizable config.
		/// - Parameters:
		///   - name:  Custom name for this container. If not set, a random one will be generated by Docker. Must match `/?[a-zA-Z0-9][a-zA-Z0-9_.-]+` (must start with a letter or number, then must only contain letters, numbers, _, ., -)
		/// - Returns: Returns  the created `Container`'s ID.
		public func create(name: String? = nil, spec: ContainerConfig) async throws -> CreateContainerEndpoint.Response {
			try await client.run(CreateContainerEndpoint(name: name, spec: spec, logger: client.logger))
		}

		/// Updates an existing container.
		/// - Parameters:
		///   - nameOrId: Name or id of a container.
		///   - spec: a `ContainerUpdate` representing the configuration to update.
		/// - Throws: Errors that can occur when executing the request.
		public func update(_ nameOrId: String, spec: ContainerUpdate) async throws {
			try await client.run(UpdateContainerEndpoint(nameOrId: nameOrId, spec: spec))
		}
		
		/// Starts a container. Before starting it needs to be created.
		/// - Parameter nameOrId: Name or Id of the`Container`.
		/// - Throws: Errors that can occur when executing the request.
		public func start(_ nameOrId: String) async throws {
			try await client.run(StartContainerEndpoint(containerId: nameOrId))
		}
		
		/// Stops a container. Before stopping it needs to be created and started.
		/// - Parameters:
		///   - nameOrId: Name or Id of the`Container`.
		///   - timeout: Number of seconds to wait for the containert to stop, before killing it.
		/// - Throws: Errors that can occur when executing the request.
		public func stop(_ nameOrId: String, timeout: UInt? = nil) async throws {
			try await client.run(StopContainerEndpoint(containerId: nameOrId, timeout: timeout))
		}
		
		/// Kills a running container by sending it a Unix signal.
		/// - Parameters:
		///   - nameOrId: Name or Id of the`Container`.
		///   - signal: Unix signal to be sent, defaults to `kill` (SIGKILL).
		/// - Throws: Errors that can occur when executing the request.
		public func kill(_ nameOrId: String, with signal: UnixSignal = .kill) async throws {
			try await client.run(KillContainerEndpoint(containerId: nameOrId, signal: signal))
		}
		
		/// Pauses a container.
		/// Uses the freezer cgroup to suspend all processes in a container.
		/// Traditionally, when suspending a process the SIGSTOP signal is used, which is observable by the process being suspended.
		/// With the freezer cgroup the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.
		/// - Parameter nameOrId: Name or Id of the`Container`.
		/// - Throws: Errors that can occur when executing the request.
		public func pause(_ nameOrId: String) async throws {
			try await client.run(PauseUnpauseContainerEndpoint(nameOrId: nameOrId, unpause: false))
		}
		
		/// Resume a container which has been paused.
		/// - Parameter nameOrId: Name or Id of the`Container`.
		/// - Throws: Errors that can occur when executing the request.
		public func unpause(_ nameOrId: String) async throws {
			try await client.run(PauseUnpauseContainerEndpoint(nameOrId: nameOrId, unpause: true))
		}
		
		/// Renames a container.
		/// - Parameters:
		///   - nameOrId: Name or Id of the`Container`.
		///   - to: The new name of the `Container`.
		/// - Throws: Errors that can occur when executing the request.
		public func rename(_ nameOrId: String, to newName: String) async throws {
			try await client.run(RenameContainerEndpoint(containerId: nameOrId, newName: newName))
		}
		
		/// Removes an existing container.
		/// - Parameters:
		///   - nameOrId: Name or Id of the`Container`.
		///   - force: Delete even if it is running
		///   - removeAnonymousVolumes: Remove anonymous volumes associated with the container.
		/// - Throws: Errors that can occur when executing the request.
		public func remove(_ nameOrId: String, force: Bool = false, removeAnonymousVolumes: Bool = false) async throws {
			try await client.run(RemoveContainerEndpoint(containerId: nameOrId, force: force, removeAnonymousVolumes: removeAnonymousVolumes))
		}
		
		/// Gets the logs of a container.
		/// - Parameters:
		///   - container: Instance of an `Container`.
		///   - stdErr: Whether to return log lines from the standard error.
		///   - stdOut: Whether to return log lines from the standard output.
		///   - timestamps: Whether to return the timestamp of each log line
		///   - follow: Whether to wait for new logs to become available and stream them.
		///   - tail: Number of last existing log lines to return. Default: all.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns  a  sequence of `DockerLogEntry`.
		public func logs(container: Container, stdErr: Bool = true, stdOut: Bool = true, timestamps: Bool = true, follow: Bool = false, tail: UInt? = nil, since: Date = .distantPast, until: Date = .distantFuture) async throws -> AsyncThrowingStream<DockerLogEntry, Error> {
			let endpoint = GetContainerLogsEndpoint(
				containerId: container.id,
				stdout: stdOut,
				stderr: stdErr,
				timestamps: timestamps,
				follow: follow,
				tail: tail == nil ? "all" : "\(tail!)",
				since: since,
				until: until
			)
			let response = try await client.run(
				endpoint,
				// Arbitrary timeouts.
				// TODO: should probably make these configurable
				timeout: follow ? .hours(12) : .seconds(60),
				hasLengthHeader: !container.config.tty,
				separators: [UInt8(13)]
			)
			
			return try await endpoint.map(response: response, tty: container.config.tty)
		}
		
		/// Attaches to a container. Allows to retrieve a stream of the container output, and sending commands if it listens on the standard input.
		/// - Parameters:
		///   - container: Instance of an `Container`.
		///   - stream: Whether to return stream
		///   - logs: Whether to return log lines from the standard output.
		///   - detachKeys: Override the key sequence for detaching a container. Format is a single character `[a-Z]`, or` ctrl-<value>` where `<value>` is one of: a-z, @, ^, [, ,, or _.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns  a `ContainerAttach` allowing to fetch the container output as well as sending input/commands to it.
		public func attach(container: Container, stream: Bool, logs: Bool, detachKeys: String? = nil) async throws -> ContainerAttachEndpoint.AttachControl {
			let ep = ContainerAttachEndpoint(client: client, nameOrId: container.id, stream: true, logs: false)
			return try await ep.connect()
		}
		
		/// Deletes all stopped containers.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns an `EventLoopFuture` with a list of deleted `Container` and the reclaimed space.
		public func prune() async throws -> PrunedContainers {
			let response =  try await client.run(PruneContainersEndpoint())
			return PrunedContainers(
				containersIds: response.ContainersDeleted?.map({ .init($0)}) ?? [],
				reclaimedSpace: response.SpaceReclaimed
			)
		}
		
		public struct PrunedContainers {
			/// IDs of the containers that were deleted.
			let containersIds: [String]
			
			/// Disk space reclaimed in bytes.
			let reclaimedSpace: UInt64
		}
		
		/// Blocks until a container stops, then returns the exit code.
		/// - Parameter nameOrId: Name or ID of the`Container`.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns the exit code of the`Container` (`0` meaning success/no error).
		public func wait(_ nameOrId: String) async throws -> Int {
			let response = try await client.run(WaitContainerEndpoint(nameOrId: nameOrId))
			return response.StatusCode
		}
		
		/// Returns which files in a container's filesystem have been added, deleted, or modified.
		/// - Parameter nameOrId: Name or ID of the`Container`.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns a list of `ContainerFsChange`.
		public func getFsChanges(_ nameOrId: String) async throws -> [ContainerFsChange] {
			return try await client.run(GetContainerChangesEndpoint(nameOrId: nameOrId))
		}
		
		/// Returns `ps`-like raw info about processes running in a container
		/// - Parameters:
		///   - nameOrId: Name or ID of the`Container`.
		///   - psArgs: options to pass to the `ps` command. Defaults to `-ef`
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns a `ContainerTop`instance.
		public func processes(_ nameOrId: String, psArgs: String = "-ef") async throws -> ContainerTopEndpoint.Response {
			return try await client.run(ContainerTopEndpoint(nameOrId: nameOrId, psArgs: psArgs))
		}
		
		/// Returns a stream of metrics about a running container.
		/// - Parameters:
		///   - nameOrId: Name or ID of the`Container`.
		///   - stream: Whether to continuously poll the container for metrics and stream them.
		///   - oneShot: Set to `true`to only get a single stat instead of waiting for 2 cycles. Must be used with `stream`=`false`.
		/// - Throws: Errors that can occur when executing the request.
		/// - Returns: Returns a stream of `ContainerStats`instances.
		public func stats(_ nameOrId: String, stream: Bool = true, oneShot: Bool = false) async throws -> AsyncThrowingStream<ContainerStats, Error> {
			let endpoint = GetContainerStatsEndpoint(nameOrId: nameOrId, stream: stream, oneShot: oneShot)
			let stream = try await client.run(endpoint, timeout: .hours(12), hasLengthHeader: false, separators: [UInt8(13)])
			return try await endpoint.map(response: stream, as: ContainerStats.self)
		}
	}
}

