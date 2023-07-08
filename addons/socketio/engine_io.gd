class_name EngineIO
extends RefCounted

signal connected
signal disconnected
signal message_received

enum EngineState { NOT_CONNECTED, CONNECTING, CONNECTED }
enum MessageType { OPEN, CLOSE, PING, PONG, MESSAGE, UPGRADE, NOOP }

var sid = ""
var ping_interval = 25000
var ping_timeout = 20000
var max_payload = 1000000

var socket = WebSocketPeer.new()
var socket_state: EngineState = EngineState.NOT_CONNECTED
var socket_thread: Thread
var mutex := Mutex.new()

func connect_to_url(url, headers: PackedStringArray = []):
	socket.handshake_headers = headers
	socket.connect_to_url(url + "/socket.io/?EIO=4&transport=websocket")
	socket_state = EngineState.CONNECTING
	socket_thread = Thread.new()
	socket_thread.start(socket_poll)

func send_text(content: String):
	send_type(MessageType.MESSAGE, content)

func send_type(type: MessageType, content: String = ""):
	mutex.lock()
	socket.send_text(str(type) + content)
	mutex.unlock()

func pong():
	send_type(MessageType.PONG)

func socket_poll():
	while true:
		mutex.lock()
		socket.poll()
		var state = socket.get_ready_state()
		mutex.unlock()
		if state == WebSocketPeer.STATE_OPEN:
			mutex.lock()
			while socket.get_available_packet_count():
				var packet = socket.get_packet()
				var content = packet.get_string_from_utf8()
				var packet_type = int(content[0])
				match packet_type:
					MessageType.OPEN:
						var data = JSON.parse_string(content.substr(1))
						sid = data.sid
						ping_interval = data.pingInterval
						ping_timeout = data.pingTimeout
						max_payload = data.maxPayload
						_on_connected.call_deferred()
					MessageType.CLOSE:
						_on_closed.call_deferred()
						mutex.unlock()
						return
					MessageType.PING:
						pong()
					MessageType.MESSAGE:
						var message = content.substr(1)
						_on_msg_received.call_deferred(message)
			mutex.unlock()
		elif state == WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		elif state == WebSocketPeer.STATE_CLOSED:
			mutex.lock()
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			mutex.unlock()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			_on_closed.call_deferred()
			return

func _on_connected():
	connected.emit()

func _on_msg_received(msg):
	message_received.emit(msg)

func _on_closed():
	disconnected.emit()
	socket_thread.wait_to_finish()
