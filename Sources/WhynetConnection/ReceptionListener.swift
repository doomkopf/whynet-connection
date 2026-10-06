public protocol ReceptionListener: Sendable {
    func onReceived(connection: Connection, frame: String) async
}
