# Whynet-Connection

A TCP server and client for sending and receiving zero terminated string frames supporting automatic connect, reconnect and connection pooling.

## Public components

### Server
A TCP server that supports receiving and responding zero terminated string frames.

### Client
A TCP client for a single connnection that supports sending and receiving zero terminated string frames. It connects and reconnects automatically.

### MultiClient
The same as "Client", but supports sending to multiple servers maintaing a pool of Clients.
