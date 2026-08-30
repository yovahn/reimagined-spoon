extends CanvasLayer

@onready var status: Label = $Panel/Margin/Rows/Status
@onready var address: LineEdit = $Panel/Margin/Rows/Address
@onready var port: LineEdit = $Panel/Margin/Rows/Port
@onready var host_button: Button = $Panel/Margin/Rows/Buttons/Host
@onready var join_button: Button = $Panel/Margin/Rows/Buttons/Join


func _ready() -> void:
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	Network.status_changed.connect(_set_status)
	_set_status(Network.status_text)


func _host() -> void:
	Network.host(_read_port())


func _join() -> void:
	Network.join(address.text.strip_edges(), _read_port())


func _read_port() -> int:
	var value := port.text.to_int()
	return value if value > 0 else Network.DEFAULT_PORT


func _set_status(message: String) -> void:
	status.text = message
