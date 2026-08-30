extends CanvasLayer

@onready var status: Label = $Panel/VBox/Status
@onready var address: LineEdit = $Panel/VBox/Address
@onready var port: LineEdit = $Panel/VBox/Port
@onready var host_button: Button = $Panel/VBox/Buttons/Host
@onready var join_button: Button = $Panel/VBox/Buttons/Join

func _ready() -> void:
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	Network.status_changed.connect(_set_status)
	_set_status(Network.status_text)

func _host() -> void:
	Network.host(_read_port())

func _join() -> void:
	var host_address := address.text.strip_edges()
	Network.join(host_address if not host_address.is_empty() else "127.0.0.1", _read_port())

func _read_port() -> int:
	var value := port.text.to_int()
	return value if value > 0 else Network.DEFAULT_PORT

func _set_status(message: String) -> void:
	status.text = message
