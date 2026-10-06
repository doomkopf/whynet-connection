import WhynetCommons

struct SendQueueEntry {
    let frame: String
    let callback: SendCallback
}

struct SendQueueEntryWithKey {
    let key: Int
    let entry: SendQueueEntry
}

class SendQueue: CacheListener {
    private let cache: any Cache<Int, SendQueueEntry>
    private var keyCounter = 0

    init(
        entryEvictionTimeMillis: Int64,
        maxEntries: Int,
    ) throws {
        cache = try CacheImpl<Int, SendQueueEntry>(
            entryEvictionTimeMillis: entryEvictionTimeMillis,
            maxEntries: maxEntries,
        )

        cache.setListener(self)
    }

    func scheduledTasks() {
        cache.cleanup()
    }

    func onEntryEvicted(key: Int, value: SendQueueEntry) {
        value.callback(false)
    }

    func enqueue(_ elem: SendQueueEntry) {
        cache.put(key: keyCounter, value: elem)

        keyCounter += 1
        if keyCounter > 999999 {
            keyCounter = 0
        }
    }

    func remove(_ key: Int) {
        _ = cache.remove(key)
    }

    func getFirst() -> SendQueueEntryWithKey? {
        // Right - we're not really getting the first entry from the queue and cache isn't even a queue...
        // But sending the frames in the right order isn't a requirement
        guard let entry = cache.getAnyEntry() else {
            return nil
        }

        return SendQueueEntryWithKey(key: entry.key, entry: entry.value)
    }

    var hasEntries: Bool {
        cache.size > 0
    }
}
