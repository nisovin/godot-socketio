extends Node

var io: SocketIO

func _ready() -> void:
	io = SocketIO.new("ws://localhost:3000")
	io.on("chat", self, "_on_chat")

func _on_chat(msg):
	print(msg)

func _on_line_edit_text_submitted(new_text: String) -> void:
	io.emit("chat", new_text)
