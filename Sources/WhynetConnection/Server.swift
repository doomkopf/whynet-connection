import NIO

/// A TCP server that supports receiving and responding zero terminated string frames.
public actor Server {
    private var eventLoopGroup: EventLoopGroup?
    private var serverChannel: Channel?

    public init() {}

    public func start(port: Int, receptionListener: ReceptionListener) async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.eventLoopGroup = eventLoopGroup

        let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ChannelInboundHandlerImpl(receptionListener))
            }
            .bind(host: "0.0.0.0", port: port)
            .get()
        self.serverChannel = serverChannel
    }

    public func shutdown() async {
        do {
            try await serverChannel?.close()
        } catch {
            print(error)
        }
        do {
            try await eventLoopGroup?.shutdownGracefully()
        } catch {
            print(error)
        }
    }
}
