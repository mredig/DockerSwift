import NIOHTTP1
import NIO
import NIOFoundationCompat
import Foundation

protocol Endpoint {
    associatedtype Response
    associatedtype Body: Codable
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? {get}
    var body: Body? { get }
}

extension SimpleEndpoint {
    public var body: Body? {
        return nil
    }
    
    public var headers: HTTPHeaders? {
        return nil
    }
}

protocol SimpleEndpoint: Endpoint where Response: Codable {}

protocol PipelineEndpoint: SimpleEndpoint {
    func map(data: String) throws -> Self.Response
}

protocol StreamingEndpoint: Endpoint where Response == AsyncThrowingStream<ByteBuffer, Error> {}

extension StreamingEndpoint {
    var headers: HTTPHeaders? { nil }
    var body: Body? { nil }
}

/// A Docker API endpoint that receives a stream of bytes in the request body
protocol UploadEndpoint: Endpoint where Response == AsyncThrowingStream<ByteBuffer, Error>, Body == ByteBuffer {}

extension UploadEndpoint {
    var headers: HTTPHeaders? { nil }
}

/// A Docker API endpoint that returns  a progressive stream of JSON objects separated by line returns
class JSONStreamingEndpoint<T>: StreamingEndpoint where T: Codable {
    internal init(path: String, method: HTTPMethod = .GET) {
        self.path = path
        self.method = method
    }
    
    private(set) internal var path: String
    
    private(set) internal var method: HTTPMethod = .GET
    
    typealias Response = AsyncThrowingStream<ByteBuffer, Error>
    
    typealias Body = NoBody
    
    private let decoder = JSONDecoder()
    
    func map(response: Response, as: T.Type) async throws -> AsyncThrowingStream<T, Error>  {
        return AsyncThrowingStream<T, Error> { continuation in
            Task {
                for try await var buffer in response {
                    let totalDataSize = buffer.readableBytes
                    while buffer.readerIndex < totalDataSize {
                        if buffer.readableBytes == 0 {
                            continuation.finish()
                        }
                        guard let data = buffer.readData(length: buffer.readableBytes) else {
                            continuation.finish(throwing: DockerLogDecodingError.dataCorrupted("Unable to read \(totalDataSize) bytes as Data"))
                            return
                        }
                        let splat = data.split(separator: 10 /* ascii code for \n */)
                        guard splat.count >= 1 else {
                            continuation.finish(throwing: DockerError.unknownResponse("Expected json terminated by line return"))
                            return
                        }
                        do {
                            let model = try decoder.decode(T.self, from: splat.first!)
                            continuation.yield(model)
                        }
                        catch(let error) {
                            continuation.finish(throwing: error)
                        }
                    }
                }
                continuation.finish()
            }
        }
    }
}

