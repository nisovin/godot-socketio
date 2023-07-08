class_name EngineIO
extends Reference

signal connected
signal disconnected
signal message_received

enum EngineState { NOT_CONNECTED, CONNECTING, CONNECTED }
enum MessageType { OPEN, CLOSE, PING, PONG, MESSAGE, UPGRADE, NOOP }

var sid = ""
var ping_interval = 25000
var ping_timeout = 20000
var max_payload = 1000000

var socket = WebSocketClient.new()

func connect_to_url(url, headers: PoolStringArray = []):
	#socket.connect("connection_established", self, "_on_connected")
	socket.connect("data_received", self, "_on_data")
	socket.connect("connection_closed", self, "_on_closed")
	socket.connect_to_url(url + "/socket.io/?EIO=4&transport=websocket", [], false, headers)
	Engine.get_main_loop().connect("idle_frame", self, "socket_poll")

func send_text(content: String):
	send_type(MessageType.MESSAGE, content)

func send_type(type, content: String = ""):
	#print("send:" + str(type) + content)
	var data = (str(type) + content).to_utf8()
	socket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	socket.get_peer(1).put_packet(data)

func pong():
	send_type(MessageType.PONG)

func socket_poll():
	socket.poll()

func _on_data():
	var packet = socket.get_peer(1).get_packet()
	var content = packet.get_string_from_utf8()
	#print("packet:", content)
	var packet_type = int(content[0])
	match packet_type:
		MessageType.OPEN:
			var data = JSON.parse(content.substr(1)).result
			sid = data.sid
			ping_interval = data.pingInterval
			ping_timeout = data.pingTimeout
			max_payload = data.maxPayload
			call_deferred("emit_signal", "connected")
		MessageType.CLOSE:
			emit_signal("disconnected")
			return
		MessageType.PING:
			pong()
		MessageType.MESSAGE:
			var message = content.substr(1)
			emit_signal("message_received", message)

func _on_closed(clean):
	print("Closed, clean:", clean)
