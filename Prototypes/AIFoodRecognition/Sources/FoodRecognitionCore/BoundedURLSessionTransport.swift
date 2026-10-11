import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ephemeral HTTPS requests: no disk cache, cookies, redirects, retries, or background uploads.
public struct BoundedURLSessionTransport: BackendHTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> BackendHTTPResponse {
        guard request.url?.scheme == "https" else { throw EstimationError.invalidConfiguration }
        let operation = HTTPRequestOperation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                operation.start(request, continuation: continuation)
            }
        }, onCancel: { operation.cancel() })
    }
}

/// All mutable state is protected by lock; delegate callbacks and task cancellation can race.
private final class HTTPRequestOperation: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var continuation: CheckedContinuation<BackendHTTPResponse, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    private var data = Data()

    func start(_ request: URLRequest, continuation: CheckedContinuation<BackendHTTPResponse, Error>) {
        lock.lock()
        if completed {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
        lock.unlock()
    }

    func cancel() { finish(.failure(CancellationError())) }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse,
              response.expectedContentLength <= FoodBackendClient.maximumResponseBytes else {
            completionHandler(.cancel)
            finish(.failure(EstimationError.invalidResponse))
            return
        }
        lock.lock()
        self.response = http
        let isCompleted = completed
        lock.unlock()
        completionHandler(isCompleted ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        lock.lock()
        let exceedsLimit = chunk.count > FoodBackendClient.maximumResponseBytes - data.count
        if !completed && !exceedsLimit { data.append(chunk) }
        lock.unlock()
        if exceedsLimit { finish(.failure(EstimationError.invalidResponse)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)); return }
        lock.lock()
        let result = response.map {
            BackendHTTPResponse(data: data, statusCode: $0.statusCode, contentType: $0.value(forHTTPHeaderField: "Content-Type"))
        }
        lock.unlock()
        finish(result.map(Result.success) ?? .failure(EstimationError.invalidResponse))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward a bearer token or current meal image to a redirected host.
        completionHandler(nil)
    }

    private func finish(_ result: Result<BackendHTTPResponse, Error>) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        completed = true
        let continuation = self.continuation
        let session = self.session
        self.continuation = nil
        self.session = nil
        self.task = nil
        self.response = nil
        data = Data()
        lock.unlock()
        session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }
}
