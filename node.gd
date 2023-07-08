extends Node

var io: SocketIO

func _ready() -> void:
	io = SocketIO.new("ws://localhost:3000")
	io.on("connect", func():
		print("CONNECTED!")
		io.emit("name", "Bob")
	)
	io.on("chat", func(msg):
		print(msg)
		%Label.text += msg + "\n"
	)

func _on_line_edit_text_submitted(new_text: String) -> void:
	io.emit("chat", new_text)
	%LineEdit.text = ""
