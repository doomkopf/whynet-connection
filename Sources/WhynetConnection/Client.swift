import WhynetCommons

/// A TCP client for a single connnection that supports sending and receiving zero terminated string frames. It connects and reconnects automatically.
public actor Client {
    private let host: String
    private let port: Int
    private let sendQueue: SendQueue
    private let connector: Connector

    private let task: ScheduledTask
    private var connecting = false
    private var connection: Connection?

    public init(
        host: String,
        port: Int,
        sendQueueMaxEntries: Int,
        sendQueueEntryEvictionTimeMillis: Int64,
        sendQueueScheduleIntervalMillis: Int64,
        receptionListener: ReceptionListener,
    ) throws {
        self.host = host
        self.port = port

        sendQueue = try SendQueue(
            entryEvictionTimeMillis: sendQueueEntryEvictionTimeMillis,
            maxEntries: sendQueueMaxEntries,
        )
        task = scheduleInterval(millis: sendQueueScheduleIntervalMillis)

        connector = Connector(
            host: host,
            port: port,
            receptionListener: receptionListener,
        )

        task.setFuncNotAwaiting {
            await self.scheduledTasks()
        }
    }

    private func scheduledTasks() {
        sendQueue.scheduledTasks()
    }

    /// Sends a frame returing false in case it timed out.
    public func send(_ frame: String) async -> Bool {
        await withCheckedContinuation { c in
            sendCallback(frame: frame) { sendError in
                c.resume(returning: sendError)
            }
        }
    }

    /// The callback based equivalent of "send".
    public func sendCallback(frame: String, callback: @escaping SendCallback) {
        sendQueue.enqueue(SendQueueEntry(frame: frame, callback: callback))
        Task {
            await processSendQueue()
        }
    }

    private func scheduleProcessSendQueue() {
        scheduleOnce(
            millis: 50,
            taskFunc: {
                await self.processSendQueue()
            })
    }

    private func processSendQueue() async {
        if !sendQueue.hasEntries {
            return
        }

        if connecting {
            return
        }

        if connection == nil {
            connecting = true
            connection = await connector.connect()
            connecting = false
        }

        if connection != nil {
            await sendDirectAllFromQueue()
        } else {
            scheduleProcessSendQueue()
        }
    }

    private func sendDirectAllFromQueue() async {
        while let entry = sendQueue.getFirst() {
            if !(await sendDirectOrFireRetry(frame: entry.entry.frame)) {
                return
            }
            sendQueue.remove(entry.key)
            entry.entry.callback(true)
        }
    }

    private func sendDirectOrFireRetry(frame: String) async -> Bool {
        guard let localConnection = connection else {
            return false
        }
        if (await localConnection.write(frame)) != nil {
            if let reReadLocalConnection = connection {
                if localConnection.isSame(reReadLocalConnection) {
                    connection = nil
                    await localConnection.close()
                }
            }
            Task {
                await processSendQueue()
            }
            return false
        }
        return true
    }

    public func shutdown() async {
        await task.cancel()
        await connection?.close()
        await connector.shutdown()
    }
}
