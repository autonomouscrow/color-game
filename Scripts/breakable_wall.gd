extends enemy


@onready var color: ColorRect = $ColorRect

var healthPercent: float = 1

func _physics_process(delta: float) -> void:
	if health > 0:
		healthPercent = float(health) / max_health
		var shade: int = 255 - (healthPercent * 255)
		color.color = Color8(shade, shade, shade, 255)
