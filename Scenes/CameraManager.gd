extends Camera2D

var current_camera: Camera2D

func _ready() -> void:
	register_camera(self)
	
func register_camera(camera: Camera2D) -> void:
	current_camera = camera

func set_room_limits(left: int, top: int, right: int, bottom: int) -> void:
	current_camera.position_smoothing_enabled = false
	
	current_camera.limit_left = left
	current_camera.limit_top = top
	current_camera.limit_right = right
	current_camera.limit_bottom = bottom
	
	current_camera.align()                
	current_camera.force_update_scroll()  
	current_camera.reset_smoothing()      
	await get_tree().physics_frame
	await get_tree().process_frame
	
	current_camera.position_smoothing_enabled = true
