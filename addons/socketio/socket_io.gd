class_name SocketIO
extends RefCounted

enum MessageType { CONNECT, DISCONNECT, EVENT, ACK, CONNECT_ERROR, BINARY_EVENT, BINARY_ACK }

var _engine: EngineIO
var _next_event_id := 1
var _ack_waiters := {}

func _init(url: String, headers: PackedStringArray = []):
	_engine = EngineIO.new()
	_engine.connected.connect(_on_engine_connected)
	_engine.message_received.connect(_on_engine_message_received)
	_engine.connect_to_url(url, headers)

func on(event: String, callable: Callable):
	if not has_user_signal(event):
		add_user_signal(event)
	connect(event, callable)

func emit(event: String, data: Variant = null, data2: Variant = null, data3: Variant = null):
	var array = [event]
	if data != null:
		array.append(data)
	if data2 != null:
		array.append(data2)
	if data3 != null:
		array.append(data3)
	_send_message(MessageType.EVENT, JSON.stringify(array))

func emit_with_ack(event: String, data: Variant):
	var ack_waiter = AckWaiter.new()
	var event_id = _next_event_id
	_next_event_id += 1
	_ack_waiters[event_id] = ack_waiter
	emit(event, data)
	var result = await ack_waiter.received
	_ack_waiters.erase(event_id)
	return result

func _send_message(type: MessageType, content: String = "", ack_id = -1):
	if ack_id > 0:
		_engine.send_text(str(type) + str(ack_id) + content)
	else:
		_engine.send_text(str(type) + content)

func _on_engine_connected():
	_send_message(MessageType.CONNECT)

func _on_engine_message_received(message):
	var message_type = int(message[0])
	var message_content = message.substr(1)

	match message_type:
		MessageType.EVENT:
			var array = JSON.parse_string(message_content)
			if array == null or not array is Array:
				push_error("Invalid EVENT!")
				return
			if has_user_signal(array[0]):
				if array.size() == 1:
					emit_signal(array[0])
				elif array.size() == 2:
					emit_signal(array[0], array[1])
				elif array.size() == 3:
					emit_signal(array[0], array[1], array[2])

		MessageType.ACK:
			var comma = message_content.find(",")
			var event_id = int(message_content.substr(0, comma - 1))
			var array = JSON.parse_string(message_content.substr(comma + 1))
			if not event_id in _ack_waiters or array == null or not array is Array:
				push_error("Invalid ACK!")
				return
			_ack_waiters[event_id].received.emit(array)

class AckWaiter:
	signal received
