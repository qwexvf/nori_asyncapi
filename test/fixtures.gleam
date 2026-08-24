//// Shared spec fixtures for the test suite.

/// WS server, one send op, $ref to a components message with an object payload.
pub const ws_counts = "asyncapi: 3.0.0
info:
  title: RT
  version: 1.0.0
servers:
  rt:
    host: rt.example.com
    protocol: ws
channels:
  counts:
    address: server.counts
    messages:
      countUpdate:
        $ref: '#/components/messages/CountUpdate'
operations:
  onCounts:
    action: send
    channel:
      $ref: '#/channels/counts'
    messages:
      - $ref: '#/channels/counts/messages/countUpdate'
components:
  messages:
    CountUpdate:
      name: CountUpdate
      payload:
        type: object
        required:
          - serverId
          - players
        properties:
          serverId:
            type: string
          players:
            type: integer
          map:
            type: string
"

/// SSE server (protocol http), one send op.
pub const sse_feed = "asyncapi: 3.0.0
info:
  title: Feed
  version: 2.0.0
servers:
  feed:
    host: feed.example.com
    protocol: sse
channels:
  ticks:
    address: ticks
    messages:
      tick:
        $ref: '#/components/messages/Tick'
operations:
  onTick:
    action: send
    channel:
      $ref: '#/channels/ticks'
    messages:
      - $ref: '#/channels/ticks/messages/tick'
components:
  messages:
    Tick:
      payload:
        type: object
        properties:
          value:
            type: number
"

/// Inline message (no $ref indirection) with a primitive payload.
pub const inline_primitive = "asyncapi: 3.0.0
info:
  title: Inline
  version: 1.0.0
channels:
  pings:
    address: pings
    messages:
      ping:
        payload:
          type: string
operations:
  onPing:
    action: receive
    channel:
      $ref: '#/channels/pings'
    messages:
      - $ref: '#/channels/pings/messages/ping'
"

/// Array payload + enum property, referenced from components/schemas.
pub const array_and_enum = "asyncapi: 3.0.0
info:
  title: Shapes
  version: 1.0.0
channels:
  events:
    address: events
    messages:
      batch:
        payload:
          type: array
          items:
            type: string
      status:
        payload:
          type: string
          enum:
            - active
            - closed
operations:
  onBatch:
    action: send
    channel:
      $ref: '#/channels/events'
    messages:
      - $ref: '#/channels/events/messages/batch'
  onStatus:
    action: send
    channel:
      $ref: '#/channels/events'
    messages:
      - $ref: '#/channels/events/messages/status'
"

/// Operation whose message $ref points nowhere.
pub const dangling_ref = "asyncapi: 3.0.0
info:
  title: Dangling
  version: 1.0.0
channels:
  c:
    address: c
operations:
  op:
    action: send
    channel:
      $ref: '#/channels/c'
    messages:
      - $ref: '#/components/messages/DoesNotExist'
"

/// One channel with two `send` messages (Alpha, Beta) — must demux by type.
pub const multi_send = "asyncapi: 3.0.0
info:
  title: Multi
  version: 1.0.0
servers:
  rt:
    host: rt.example.com
    protocol: ws
channels:
  run:
    address: run
    messages:
      a:
        $ref: '#/components/messages/Alpha'
      b:
        $ref: '#/components/messages/Beta'
operations:
  onAlpha:
    action: send
    channel:
      $ref: '#/channels/run'
    messages:
      - $ref: '#/channels/run/messages/a'
  onBeta:
    action: send
    channel:
      $ref: '#/channels/run'
    messages:
      - $ref: '#/channels/run/messages/b'
components:
  messages:
    Alpha:
      name: Alpha
      payload:
        type: object
        properties:
          a:
            type: string
    Beta:
      name: Beta
      payload:
        type: object
        properties:
          b:
            type: integer
"
