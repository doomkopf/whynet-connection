import WhynetCommons

/// The same as "Client", but supports sending to multiple servers maintaing a pool of Clients.
public actor MultiClient: CacheListener {
    private let receptionListener: ReceptionListener
    private let sendQueueMaxEntries: Int
    private let sendQueueEntryEvictionTimeMillis: Int64
    private let sendQueueScheduleIntervalMillis: Int64

    private let clients: any Cache<HostAddress, Client>
    private let task: ScheduledTask

    public init(
        sendQueueMaxEntries: Int,
        sendQueueEntryEvictionTimeMillis: Int64,
        sendQueueScheduleIntervalMillis: Int64,
        clientCacheEvictionTimeMillis: Int64,
        maxClients: Int,
        receptionListener: ReceptionListener,
    ) throws {
        self.receptionListener = receptionListener
        self.sendQueueMaxEntries = sendQueueMaxEntries
        self.sendQueueEntryEvictionTimeMillis = sendQueueEntryEvictionTimeMillis
        self.sendQueueScheduleIntervalMillis = sendQueueScheduleIntervalMillis

        clients = try CacheImpl(
            entryEvictionTimeMillis: clientCacheEvictionTimeMillis,
            maxEntries: maxClients,
        )

        task = scheduleInterval(millis: 1000)

        clients.setListener(self)

        task.setFuncNotAwaiting {
            await self.scheduledTasks()
        }
    }

    private func scheduledTasks() {
        self.clients.cleanup()
    }

    public nonisolated func onEntryEvicted(key: HostAddress, value: Client) {
        shutdownClient(value)
    }

    /// Sends a frame to the given host returing false in case it timed out.
    public func send(host: HostAddress, frame: String) async -> Bool {
        await withCheckedContinuation { c in
            sendCallback(host: host, frame: frame) { sendError in
                c.resume(returning: sendError)
            }
        }
    }

    /// The callback based equivalent of "send".
    public func sendCallback(host: HostAddress, frame: String, callback: @escaping SendCallback) {
        let client = getOrCreateClient(host)

        Task {
            await client.sendCallback(frame: frame, callback: callback)
        }
    }

    private func getOrCreateClient(_ host: HostAddress) -> Client {
        if let client = clients.get(key: host) {
            return client
        }

        let client = try! Client(
            host: host.host,
            port: host.port,
            sendQueueMaxEntries: sendQueueMaxEntries,
            sendQueueEntryEvictionTimeMillis: sendQueueEntryEvictionTimeMillis,
            sendQueueScheduleIntervalMillis: sendQueueScheduleIntervalMillis,
            receptionListener: receptionListener,
        )

        clients.put(key: host, value: client)

        return client
    }

    public func shutdown() async {
        await task.cancel()
        clients.clear()
    }

    nonisolated private func shutdownClient(_ client: Client) {
        Task {
            await client.shutdown()
        }
    }
}
