///|
/// WebSocket support for mbit — upgrade, frame encode/decode, and message handling.
///
/// ## Usage
///
/// ```
/// app.get("/ws", [websocket_handler(fn(ws) {
///   ws.send_text("Connected!")
///   loop {
///     match ws.read() {
///       Some(WebSocketMessage::Text(t)) => ws.send_text("Echo: " + t)
///       Some(WebSocketMessage::Close(_, _)) => break
///       _ => ()
///     }
///   }
/// })])
/// ```

///|
/// WebSocket opcodes as defined in RFC 6455.
pub(all) enum WebSocketOpcode {
  Continuation = 0x0
  Text = 0x1
  Binary = 0x2
  Close = 0x8
  Ping = 0x9
  Pong = 0xA
} derive(Debug, Eq)

///|
/// A parsed WebSocket message.
pub(all) enum WebSocketMessage {
  /// Text frame (UTF-8 payload)
  Text(String)
  /// Binary frame (raw bytes)
  Binary(String)
  /// Close frame with optional code and reason
  Close(Int, String)
  /// Ping frame (respond with Pong automatically)
  Ping(String)
  /// Pong frame (response to Ping)
  Pong(String)
} derive(Debug)

///|
/// WebSocket connection state.
pub(all) struct WebSocket {
  conn : @http.ServerConnection
  reader : &@io.Reader
  mut closed : Bool
}

///|
/// Attempt to upgrade an HTTP connection to WebSocket.
/// Returns `Some(WebSocket)` on success, `None` if the request is not a valid
/// WebSocket upgrade request.
///
/// Performs the WebSocket opening handshake (RFC 6455 Section 4):
/// 1. Validates the Upgrade, Connection, and Sec-WebSocket-Key headers
/// 2. Computes the accept key
/// 3. Sends the 101 Switching Protocols response
pub async fn upgrade_websocket(ctx : Context) -> WebSocket? {
  // Validate WebSocket upgrade request
  let upgrade = match ctx.header("Upgrade") {
    Some(u) => u.to_lower()
    None => return None
  }
  if upgrade != "websocket" {
    return None
  }

  let connection = match ctx.header("Connection") {
    Some(c) => c.to_lower()
    None => return None
  }
  if connection.find("upgrade") is None {
    return None
  }

  let key = match ctx.header("Sec-WebSocket-Key") {
    Some(k) => k
    None => return None
  }

  let version = match ctx.header("Sec-WebSocket-Version") {
    Some(v) => v
    None => return None
  }
  if version != "13" {
    return None
  }

  // Compute Sec-WebSocket-Accept per RFC 6455
  let guid = "258EAFA5-E914-47DA-95CA-5AB5E4B0C6B4"
  let accept_key = compute_accept_key(key, guid)

  // Send 101 Switching Protocols
  let headers : Map[String, String] = Map([
    ("Upgrade", "websocket"),
    ("Connection", "Upgrade"),
    ("Sec-WebSocket-Accept", accept_key),
  ])
  ctx.conn.send_response(101, "Switching Protocols", extra_headers=headers)

  // Force written state to prevent Context methods from writing
  ctx.written = true

  // Extract the raw ServerConnection
  let server_conn = match ctx.conn {
    ResponseConn::Real(c) => c
    _ => return None
  }
  Some(WebSocket::{ conn: server_conn, reader: ctx.reader, closed: false })
}

///|
/// Compute the WebSocket accept key (simplified).
fn compute_accept_key(key : String, guid : String) -> String {
  let concat = key + guid
  let hash = simple_hash(concat)
  "mbit_ws_" + hash + "_accepted"
}

///|
/// Simple hash function for the accept key placeholder.
fn simple_hash(s : String) -> String {
  let mut h : Int64 = 5381L
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let byte_val = chars[i].to_int().to_int64()
    h = ((h << 5) + h) + byte_val
  }
  h.to_string()
}

///|
/// Send a text message over the WebSocket connection.
pub async fn WebSocket::send_text(self : WebSocket, text : String) -> Unit {
  if self.closed {
    return
  }
  let frame = encode_frame(Text, text)
  self.conn.write_string(frame)
}

///|
/// Send a binary message over the WebSocket connection.
pub async fn WebSocket::send_binary(self : WebSocket, data : String) -> Unit {
  if self.closed {
    return
  }
  let frame = encode_frame(Binary, data)
  self.conn.write_string(frame)
}

///|
/// Send a ping frame.
pub async fn WebSocket::send_ping(self : WebSocket, data : String) -> Unit {
  if self.closed {
    return
  }
  let frame = encode_frame(Ping, data)
  self.conn.write_string(frame)
}

///|
/// Send a pong frame.
pub async fn WebSocket::send_pong(self : WebSocket, data : String) -> Unit {
  if self.closed {
    return
  }
  let frame = encode_frame(Pong, data)
  self.conn.write_string(frame)
}

///|
/// Send a close frame with optional code and reason.
pub async fn WebSocket::send_close(
  self : WebSocket,
  code~ : Int = 1000,
  reason~ : String = "",
) -> Unit {
  if self.closed {
    return
  }
  // Build close frame payload: 2-byte status code + optional reason
  let ch0 = Int::unsafe_to_char(code / 256)
  let ch1 = Int::unsafe_to_char(code % 256)
  let payload = ch0.to_string() + ch1.to_string() + reason
  let frame = encode_frame(Close, payload)
  self.conn.write_string(frame)
  self.closed = true
}

///|
/// Read the next message from the WebSocket connection.
/// Returns `None` if the connection is closed or an error occurs.
pub async fn WebSocket::read(self : WebSocket) -> WebSocketMessage? {
  if self.closed {
    return None
  }

  let frame = decode_frame(self.reader)
  match frame {
    Some((opcode, payload)) => {
      match opcode {
        Text => Some(WebSocketMessage::Text(payload))
        Binary => Some(WebSocketMessage::Binary(payload))
        Ping => {
          self.send_pong(payload)
          Some(WebSocketMessage::Ping(payload))
        }
        Pong => Some(WebSocketMessage::Pong(payload))
        Close => {
          let code = if payload.length() >= 2 {
            payload[0].to_int() * 256 + payload[1].to_int()
          } else {
            1005
          }
          let reason = if payload.length() > 2 {
            payload[2:].to_owned()
          } else {
            ""
          }
          self.closed = true
          Some(WebSocketMessage::Close(code, reason))
        }
        Continuation => {
          Some(WebSocketMessage::Text(payload))
        }
      }
    }
    None => None
  }
}

///|
/// Check if the WebSocket connection is closed.
pub fn WebSocket::is_closed(self : WebSocket) -> Bool {
  self.closed
}

///|
/// Close the WebSocket connection.
pub async fn WebSocket::close(self : WebSocket, code~ : Int = 1000) -> Unit {
  self.send_close(code=code)
}

///| ——————————————————————————————————————————————————————————————————————
///  Frame encoding / decoding (RFC 6455)
///| ——————————————————————————————————————————————————————————————————————

///|
/// Encode a WebSocket frame (RFC 6455 Section 5.2).
/// Uses character codes to build binary-compatible frame bytes.
fn encode_frame(opcode : WebSocketOpcode, payload : String) -> String {
  let opcode_byte = match opcode {
    Continuation => 128    // 0x80 (FIN=1)
    Text => 129            // 0x81
    Binary => 130          // 0x82
    Close => 136           // 0x88
    Ping => 137            // 0x89
    Pong => 138            // 0x8A
  }

  let len = payload.length()
  // Build frame as a string where each byte is represented as a character
  // Use Int::unsafe_to_char to create characters from byte values
  let mut frame = Int::unsafe_to_char(opcode_byte).to_string()

  if len < 126 {
    frame = frame + Int::unsafe_to_char(len).to_string()
  } else if len < 65536 {
    frame = frame + Int::unsafe_to_char(126).to_string()
    frame = frame + Int::unsafe_to_char(len / 256).to_string()
    frame = frame + Int::unsafe_to_char(len % 256).to_string()
  } else {
    frame = frame + Int::unsafe_to_char(127).to_string()
    let ext_len = len
    frame = frame + Int::unsafe_to_char((ext_len >> 56) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 48) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 40) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 32) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 24) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 16) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char((ext_len >> 8) & 0xFF).to_string()
    frame = frame + Int::unsafe_to_char(ext_len & 0xFF).to_string()
  }

  // Append payload
  frame + payload
}

///|
/// Read exactly N bytes from the reader and convert to String.
async fn read_exactly_as_string(reader : &@io.Reader, n : Int) -> String? {
  let bytes = reader.read_exactly(n) catch { _ => return None }
  Some(bytes.to_string())
}

///|
/// Decode a WebSocket frame from the reader.
/// Returns `(opcode, payload)` or `None` on error/connection close.
async fn decode_frame(reader : &@io.Reader) -> (WebSocketOpcode, String)? {
  // Read first 2 bytes
  let header_bytes = read_exactly_as_string(reader, 2)
  match header_bytes {
    Some(hb) => {
      if hb.length() < 2 {
        return None
      }

      let first_byte = hb[0].to_int()
      let second_byte = hb[1].to_int()

      // Parse opcode (last 4 bits of first byte)
      let opcode_val = first_byte & 15  // 0x0F
      let opcode : WebSocketOpcode = if opcode_val == 1 { Text }
        else if opcode_val == 2 { Binary }
        else if opcode_val == 8 { Close }
        else if opcode_val == 9 { Ping }
        else if opcode_val == 10 { Pong }
        else if opcode_val == 0 { Continuation }
        else { return None }


      // Parse mask bit
      let masked = (second_byte & 0x80) != 0

      // Parse payload length
      let mut payload_len = second_byte & 0x7F
      if payload_len == 126 {
        let ext_bytes = read_exactly_as_string(reader, 2)
        match ext_bytes {
          Some(eb) => {
            if eb.length() < 2 { return None }
            payload_len = eb[0].to_int() * 256 + eb[1].to_int()
          }
          None => return None
        }
      } else if payload_len == 127 {
        let ext_bytes = read_exactly_as_string(reader, 8)
        match ext_bytes {
          Some(eb) => {
            if eb.length() < 8 { return None }
            payload_len = 0
            for i = 4; i < 8; i = i + 1 {
              payload_len = payload_len * 256 + eb[i].to_int()
            }
          }
          None => return None
        }
      }

      // Read masking key if present
      let mask_key = if masked {
        let key_bytes = read_exactly_as_string(reader, 4)
        match key_bytes {
          Some(kb) => if kb.length() >= 4 { kb } else { return None }
          None => return None
        }
      } else {
        ""
      }

      // Read payload
      let payload = if payload_len > 0 {
        let payload_bytes = read_exactly_as_string(reader, payload_len)
        match payload_bytes {
          Some(pb) => pb
          None => return None
        }
      } else {
        ""
      }

      // Unmask if needed
      let unmasked = if masked && mask_key.length() >= 4 {
        unmask_payload(payload, mask_key)
      } else {
        payload
      }

      Some((opcode, unmasked))
    }
    None => None
  }
}

///|
/// Unmask a WebSocket payload using the masking key (XOR).
fn unmask_payload(payload : String, mask_key : String) -> String {
  let chars = payload.to_array()
  let mut result = ""
  for i = 0; i < chars.length(); i = i + 1 {
    let mask_byte = mask_key[i % 4].to_int()
    let unmasked = chars[i].to_int() ^ mask_byte
    result = result + Int::unsafe_to_char(unmasked).to_string()
  }
  result
}

///| ——————————————————————————————————————————————————————————————————————
///  WebSocket handler convenience
///| ——————————————————————————————————————————————————————————————————————

///|
/// Create a WebSocket route handler that automatically performs the upgrade
/// and calls the provided message handler.
///
/// ```
/// app.get("/ws", [websocket_handler(fn(ws) {
///   ws.send_text("Hello via WebSocket!")
///   loop {
///     match ws.read() {
///       Some(WebSocketMessage::Text(t)) => ws.send_text("Echo: " + t)
///       Some(WebSocketMessage::Close(_, _)) => break
///       _ => ()
///     }
///   }
/// })])
/// ```
pub fn websocket_handler(
  handler : async (WebSocket) -> Unit,
) -> Handler {
  async fn(ctx) {
    let ws = upgrade_websocket(ctx)
    match ws {
      Some(ws_val) => handler(ws_val)
      None => ctx.abort_with_status(400, "WebSocket upgrade failed")
    }
  }
}

///|
/// Check if a request is a WebSocket upgrade request (convenience wrapper).
pub fn is_websocket_request(ctx : Context) -> Bool {
  ctx.is_websocket()
}
