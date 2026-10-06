import Testing
import WhynetCommons

@testable import WhynetConnection

private let LOCALHOST = "127.0.0.1"
private let PORT = 9693

struct ConnectionTest {

    @Test
    func test() async throws {
        try await sendAndReceive()
        try await timeout()
        try await reconnect()
    }

    private func sendAndReceive() async throws {
        actor ServerRecListener: ReceptionListener {
            private let wait = WaitContext()
            private var frame: String?

            func awaitFrame() async -> String? {
                await wait.waitForSignal()
                return frame
            }

            func onReceived(connection: Connection, frame: String) async {
                self.frame = frame
                wait.signal()
                _ = await connection.write("\(frame) from server")
            }
        }
        let serverRecListener = ServerRecListener()

        let server = Server()
        try await server.start(port: PORT, receptionListener: serverRecListener)

        actor ClientRecListener: ReceptionListener {
            private let wait = WaitContext()
            private var frame: String?

            func awaitFrame() async -> String? {
                await wait.waitForSignal()
                return frame
            }

            func onReceived(connection: Connection, frame: String) async {
                self.frame = frame
                wait.signal()
            }
        }
        let clientRecListener = ClientRecListener()

        let client = try Client(
            host: LOCALHOST,
            port: PORT,
            sendQueueMaxEntries: 1000,
            sendQueueEntryEvictionTimeMillis: 10000,
            sendQueueScheduleIntervalMillis: 500,
            receptionListener: clientRecListener,
        )

        let success = await client.send("hello")
        #expect(success)
        #expect(await serverRecListener.awaitFrame() == "hello")
        #expect(await clientRecListener.awaitFrame() == "hello from server")

        await client.shutdown()
        await server.shutdown()
    }

    private func timeout() async throws {
        struct NoopRecListener: ReceptionListener {
            func onReceived(connection: Connection, frame: String) async {
            }
        }
        let recListener = NoopRecListener()

        let client = try Client(
            host: LOCALHOST,
            port: PORT,
            sendQueueMaxEntries: 100,
            sendQueueEntryEvictionTimeMillis: 250,
            sendQueueScheduleIntervalMillis: 100,
            receptionListener: recListener,
        )

        let success = await client.send("hello")
        #expect(!success)
    }

    private func reconnect() async throws {
        struct NoopRecListener: ReceptionListener {
            func onReceived(connection: Connection, frame: String) async {
            }
        }
        let recListener = NoopRecListener()

        let client = try Client(
            host: LOCALHOST,
            port: PORT,
            sendQueueMaxEntries: 100,
            sendQueueEntryEvictionTimeMillis: 250,
            sendQueueScheduleIntervalMillis: 100,
            receptionListener: recListener,
        )

        var server: Server

        server = Server()
        try await server.start(port: PORT, receptionListener: recListener)
        _ = await client.send("hello")  // send something to establish a connection
        // restart server
        await server.shutdown()
        server = Server()
        try await server.start(port: PORT, receptionListener: recListener)

        #expect(await client.send("hello"))

        await server.shutdown()

        #expect(!(await client.send("hello")))

        server = Server()
        try await server.start(port: PORT, receptionListener: recListener)

        #expect(await client.send("hello"))

        await server.shutdown()
        await client.shutdown()
    }
}
