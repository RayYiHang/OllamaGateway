import Foundation
import Network

// MARK: - Parsed HTTP Request

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var authorization: String? { headers["authorization"] }

    static func parse(from data: Data) -> (HTTPRequest, Int)? {
        guard let headerEndRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        guard
            let headerStr = String(
                data: data[data.startIndex..<headerEndRange.lowerBound], encoding: .utf8)
        else {
            return nil
        }

        let lines = headerStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIdx].trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let bodyStart = headerEndRange.upperBound
        let bodyData: Data

        if let clStr = headers["content-length"], let cl = Int(clStr) {
            let available = data.count - bodyStart
            guard available >= cl else { return nil }  // Need more data
            bodyData = data[bodyStart..<(bodyStart + cl)]
        } else {
            bodyData = data[bodyStart..<data.endIndex]
        }

        let totalConsumed = headerEndRange.upperBound + bodyData.count
        return (
            HTTPRequest(method: method, path: path, headers: headers, body: bodyData), totalConsumed
        )
    }
}

// MARK: - Proxy Server

final class ProxyServer {
    private var listener: NWListener?
    private let serverQueue = DispatchQueue(label: "com.ollamagateway.server", qos: .userInitiated)
    private var _config: ServerConfig
    private var _isRunning = false
    private let lock = NSLock()

    private var config: ServerConfig {
        get { lock.withLock { _config } }
        set { lock.withLock { _config = newValue } }
    }

    private var isRunning: Bool {
        get { lock.withLock { _isRunning } }
        set { lock.withLock { _isRunning = newValue } }
    }

    var onStateChange: (@Sendable (ServerStatus) -> Void)?
    var onRequestLog: (@Sendable (RequestLogEntry) -> Void)?

    init(config: ServerConfig) {
        self._config = config
    }

    func updateConfig(_ config: ServerConfig) {
        self.config = config
    }

    func start() throws {
        guard !isRunning else { return }

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = false
        tcpOptions.connectionTimeout = 30

        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .loopback

        guard let port = NWEndpoint.Port(rawValue: config.port) else {
            throw NSError(
                domain: "ProxyServer", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid port: \(config.port)"])
        }

        let newListener = try NWListener(using: params, on: port)

        newListener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.isRunning = true
                self.onStateChange?(.running)
            case .failed(let error):
                self.isRunning = false
                self.onStateChange?(.error(error.localizedDescription))
            case .cancelled:
                self.isRunning = false
                self.onStateChange?(.stopped)
            default:
                break
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        self.listener = newListener
        onStateChange?(.starting)
        newListener.start(queue: serverQueue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: serverQueue)

        var buffer = Data()

        func readMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 131072) {
                [weak self] data, _, isComplete, error in
                guard let self = self else {
                    connection.cancel()
                    return
                }

                if let data = data, !data.isEmpty {
                    buffer.append(data)
                }

                if error != nil {
                    connection.cancel()
                    return
                }

                if let (request, _) = HTTPRequest.parse(from: buffer) {
                    self.processRequest(connection, request: request)
                } else if isComplete {
                    connection.cancel()
                } else if buffer.count > 10_000_000 {
                    self.sendError(connection, status: 413, message: "Request too large")
                } else {
                    readMore()
                }
            }
        }

        readMore()
    }

    // MARK: - Request Processing

    private func processRequest(_ connection: NWConnection, request: HTTPRequest) {
        let startTime = Date()
        let clientIP = connectionAddress(connection)

        // CORS preflight (no auth required)
        if request.method == "OPTIONS" {
            handleCORSPreflight(connection, startTime: startTime, clientIP: clientIP)
            return
        }

        // Health check (no auth)
        if request.path == "/" && request.method == "GET" {
            handleHealthCheck(connection, startTime: startTime, clientIP: clientIP)
            return
        }

        // Verify API key
        guard verifyAPIKey(request) else {
            sendError(connection, status: 401, message: "Unauthorized")
            logRequest(
                method: request.method, path: request.path, status: 401, startTime: startTime,
                clientIP: clientIP)
            return
        }

        // Forward to Ollama
        forwardToOllama(connection, request: request, startTime: startTime, clientIP: clientIP)
    }

    private func verifyAPIKey(_ request: HTTPRequest) -> Bool {
        guard !config.apiKeys.isEmpty else { return false }

        guard let auth = request.authorization, auth.hasPrefix("Bearer ") else {
            return false
        }

        let token = String(auth.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        return config.apiKeys.contains(token)
    }

    // MARK: - Health Check

    private func handleHealthCheck(_ connection: NWConnection, startTime: Date, clientIP: String) {
        guard let ollamaURL = URL(string: config.ollamaBaseURL) else {
            sendError(connection, status: 502, message: "Invalid Ollama base URL")
            logRequest(
                method: "GET", path: "/", status: 502, startTime: startTime, clientIP: clientIP)
            return
        }

        let task = URLSession.shared.dataTask(with: ollamaURL) { [weak self] _, response, _ in
            let ollamaOK = (response as? HTTPURLResponse)?.statusCode == 200
            let json = "{\"status\":\"ok\",\"ollama\":\(ollamaOK)}"
            self?.sendHTTPResponse(
                connection, status: 200, contentType: "application/json", body: json)
            self?.logRequest(
                method: "GET", path: "/", status: 200, startTime: startTime, clientIP: clientIP)
        }
        task.resume()
    }

    // MARK: - Proxy to Ollama

    private func forwardToOllama(
        _ connection: NWConnection, request: HTTPRequest, startTime: Date, clientIP: String
    ) {
        guard let ollamaURL = URL(string: "\(config.ollamaBaseURL)\(request.path)") else {
            sendError(connection, status: 502, message: "Bad gateway URL")
            logRequest(
                method: request.method, path: request.path, status: 502, startTime: startTime,
                clientIP: clientIP)
            return
        }

        var urlRequest = URLRequest(url: ollamaURL)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = 300

        // Forward headers (skip hop-by-hop and headers we set explicitly)
        let skipHeaders: Set<String> = [
            "host", "origin", "authorization", "connection", "keep-alive",
            "transfer-encoding", "content-length",
        ]
        for (key, value) in request.headers where !skipHeaders.contains(key) {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Explicitly set Host header to match Ollama's expected host.
        // Ollama validates the Host header via its checkHost middleware and
        // returns 404 for unrecognised hosts. This is critical when proxying
        // through Cloudflare Tunnel or any external ingress.
        if let components = URLComponents(string: config.ollamaBaseURL),
            let host = components.host
        {
            let hostValue = components.port != nil ? "\(host):\(components.port!)" : host
            urlRequest.setValue(hostValue, forHTTPHeaderField: "Host")
        }

        // Set Origin to the Ollama base URL so Ollama's CORS check (OLLAMA_ORIGINS) passes.
        urlRequest.setValue(config.ollamaBaseURL, forHTTPHeaderField: "Origin")

        if !request.body.isEmpty {
            urlRequest.httpBody = request.body
        }

        // Use delegate for streaming
        let delegate = StreamingDelegate(
            connection: connection,
            method: request.method,
            path: request.path,
            startTime: startTime,
            clientIP: clientIP,
            onLog: { [weak self] entry in self?.onRequestLog?(entry) }
        )
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        session.dataTask(with: urlRequest).resume()
    }

    // MARK: - HTTP Response Helpers

    private func handleCORSPreflight(_ connection: NWConnection, startTime: Date, clientIP: String)
    {
        var response = "HTTP/1.1 204 No Content\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH\r\n"
        response += "Access-Control-Allow-Headers: Authorization, Content-Type\r\n"
        response += "Access-Control-Max-Age: 86400\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"
        let data = response.data(using: .utf8) ?? Data()
        connection.send(
            content: data, contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        logRequest(
            method: "OPTIONS", path: "/", status: 204, startTime: startTime, clientIP: clientIP)
    }

    private func sendHTTPResponse(
        _ connection: NWConnection, status: Int, contentType: String, body: String
    ) {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: status)
        let bodyData = body.data(using: .utf8) ?? Data()
        var response = "HTTP/1.1 \(status) \(statusText)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "\r\n"

        var data = response.data(using: .utf8) ?? Data()
        data.append(bodyData)

        connection.send(
            content: data, contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed({ _ in
                connection.cancel()
            }))
    }

    private func sendError(_ connection: NWConnection, status: Int, message: String) {
        let escaped =
            message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let json = "{\"error\":\"\(escaped)\"}"
        sendHTTPResponse(connection, status: status, contentType: "application/json", body: json)
    }

    private func connectionAddress(_ connection: NWConnection) -> String {
        if case .hostPort(let host, _) = connection.endpoint {
            return "\(host)"
        }
        return "unknown"
    }

    private func logRequest(
        method: String, path: String, status: Int, startTime: Date, clientIP: String
    ) {
        let latency = Date().timeIntervalSince(startTime) * 1000
        let entry = RequestLogEntry(
            timestamp: Date(),
            method: method,
            path: path,
            statusCode: status,
            latencyMs: latency,
            clientIP: clientIP
        )
        onRequestLog?(entry)
    }
}

// MARK: - Streaming Delegate

private final class StreamingDelegate: NSObject, URLSessionDataDelegate {
    let connection: NWConnection
    let method: String
    let path: String
    let startTime: Date
    let clientIP: String
    let onLog: (RequestLogEntry) -> Void
    var headersSent = false
    var responseStatus = 200

    init(
        connection: NWConnection, method: String, path: String, startTime: Date, clientIP: String,
        onLog: @escaping (RequestLogEntry) -> Void
    ) {
        self.connection = connection
        self.method = method
        self.path = path
        self.startTime = startTime
        self.clientIP = clientIP
        self.onLog = onLog
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        responseStatus = httpResponse.statusCode
        let statusText = HTTPURLResponse.localizedString(forStatusCode: responseStatus)
        var headerStr = "HTTP/1.1 \(responseStatus) \(statusText)\r\n"

        let skipHeaders: Set<String> = [
            "content-length", "transfer-encoding", "connection", "keep-alive",
        ]
        for (key, value) in httpResponse.allHeaderFields {
            let k = "\(key)".lowercased()
            if !skipHeaders.contains(k) {
                headerStr += "\(key): \(value)\r\n"
            }
        }
        headerStr += "Connection: close\r\n"
        headerStr += "Access-Control-Allow-Origin: *\r\n"
        headerStr += "\r\n"

        if let data = headerStr.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in }))
        }
        headersSent = true
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        connection.send(content: data, completion: .contentProcessed({ _ in }))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if let error = error {
            if !headersSent {
                let desc = error.localizedDescription
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let errBody = "{\"error\":\"upstream error: \(desc)\"}"
                let errData = errBody.data(using: .utf8) ?? Data()
                var response = "HTTP/1.1 502 Bad Gateway\r\n"
                response += "Content-Type: application/json\r\n"
                response += "Content-Length: \(errData.count)\r\n"
                response += "Connection: close\r\n"
                response += "\r\n"
                var data = response.data(using: .utf8) ?? Data()
                data.append(errData)
                connection.send(
                    content: data, contentContext: .finalMessage, isComplete: true,
                    completion: .contentProcessed({ [weak self] _ in
                        self?.connection.cancel()
                    }))
                responseStatus = 502
            } else {
                connection.send(
                    content: nil, contentContext: .finalMessage, isComplete: true,
                    completion: .contentProcessed({ [weak self] _ in
                        self?.connection.cancel()
                    }))
            }
        } else {
            connection.send(
                content: nil, contentContext: .finalMessage, isComplete: true,
                completion: .contentProcessed({ [weak self] _ in
                    self?.connection.cancel()
                }))
        }

        let latency = Date().timeIntervalSince(startTime) * 1000
        let entry = RequestLogEntry(
            timestamp: Date(),
            method: method,
            path: path,
            statusCode: responseStatus,
            latencyMs: latency,
            clientIP: clientIP
        )
        onLog(entry)
        session.finishTasksAndInvalidate()
    }
}
