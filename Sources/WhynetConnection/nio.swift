import NIO

func stringToTerminatedBuffer(_ str: String) -> ByteBuffer {
    var buffer = ByteBuffer(string: "\(str)0")
    buffer.setBytes([0], at: buffer.readableBytes - 1)
    return buffer
}

actor Connector {
    private let host: String
    private let port: Int
    private let eventLoopGroup: EventLoopGroup
    private let bootstrap: ClientBootstrap

    init(host: String, port: Int, receptionListener: ReceptionListener) {
        self.host = host
        self.port = port

        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(
                ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1
            )
            .channelInitializer { channel in
                /*
                The NIO design here makes no sense to me:
                A (ChannelHandler & Sendable) is expected here.
                The ChannelInboundHandler.channelRead is basically doing the frame decoding.
                One aspect of frame decoding is to store each chunk of data sequentially until we have a complete frame, but this requires a mutable state.
                So it expects a Sendable but a synchronous state mutation is usually needed, that's the conflict here to me.
                However, I'll assume for now that this method is only called by one thread at a time, so I will just ignore the concurrency warning here.
                */
                channel.pipeline.addHandler(ChannelInboundHandlerImpl(receptionListener))
            }
    }

    func connect() async -> Connection? {
        let task = bootstrap.connect(host: host, port: port)
        return await withCheckedContinuation { c in
            task.whenComplete { result in
                do {
                    c.resume(returning: Connection(channel: try result.get()))
                } catch {
                    c.resume(returning: nil)
                }
            }
        }
    }

    func shutdown() async {
        do {
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            print(error)
        }
    }
}

public struct Connection: Sendable {
    let channel: Channel

    public func write(_ frame: String) async -> Error? {
        return await withCheckedContinuation { c in
            channel.writeAndFlush(stringToTerminatedBuffer(frame)).whenComplete { result in
                do {
                    try result.get()
                    c.resume(returning: nil)
                } catch {
                    c.resume(returning: error)
                }
            }
        }
    }

    func isSame(_ other: Connection) -> Bool {
        channel === other.channel
    }

    func close() async {
        do {
            try await channel.close()
        } catch {
            print(error)
        }
    }
}

class ChannelInboundHandlerImpl: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let receptionListener: ReceptionListener
    private var buffer: InboundIn! = nil

    init(_ receptionListener: ReceptionListener) {
        self.receptionListener = receptionListener
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var mutableBuffer = unwrapInboundIn(data)

        if buffer == nil {
            buffer = mutableBuffer
        } else {
            buffer.writeBuffer(&mutableBuffer)
        }

        while let frame = buffer.readNullTerminatedString() {
            let channel = context.channel
            Task { [receptionListener] in
                await receptionListener.onReceived(
                    connection: Connection(channel: channel),
                    frame: frame,
                )
            }
        }
    }
}
