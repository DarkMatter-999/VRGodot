extends Node3D

var task: MediaPipeHandLandmarker
var task_file := "res://tasks/hand_landmarker.task"

@onready var image_view: TextureRect = $Control/Image
@onready var btn_back: Button = $Control/Back
@onready var btn_switch: Button = $Control/CamSelect
@onready var lhand = $LeftHand
@onready var rhand = $RightHand

var main_scene := preload("res://Main.tscn")
var cam_selection := MediaPipeCameraHelper.FACING_FRONT
var running_mode := MediaPipeTask.RUNNING_MODE_IMAGE
var delegate := MediaPipeTaskBaseOptions.DELEGATE_CPU
var camera_helper := MediaPipeCameraHelper.new()

@onready var video_player: VideoStreamPlayer = $Video
@onready var permission_dialog: AcceptDialog = $CameraPermission

func _result_callback(result: MediaPipeHandLandmarkerResult, image: MediaPipeImage, timestamp_ms: int) -> void:
	var img := image.get_image()
	show_result(img, result)
	
func _ready():
	btn_back.pressed.connect(get_tree().change_scene_to_file.bind("res://Main.tscn"))
	btn_back.pressed.connect(self._back)
	btn_switch.pressed.connect(self._select_cam)
	self._open_camera()
	camera_helper.permission_result.connect(self._permission_result)
	camera_helper.new_frame.connect(self._camera_frame)
	if OS.get_name() == "Android":
		var gpu_resources := MediaPipeGPUResources.new()
		camera_helper.set_gpu_resources(gpu_resources)
	init_task()

func _select_cam():
	if self.cam_selection == MediaPipeCameraHelper.FACING_FRONT:
		self.cam_selection = MediaPipeCameraHelper.FACING_BACK
	else:
		self.cam_selection = MediaPipeCameraHelper.FACING_FRONT
		
	self._open_camera()

func _process(delta: float) -> void:
	if video_player.is_playing():
		var texture := video_player.get_video_texture()
		if texture:
			var image := texture.get_image()
			if image:
				if not running_mode == MediaPipeTask.RUNNINE_MODE_VIDEO:
					running_mode = MediaPipeTask.RUNNINE_MODE_VIDEO
					init_task()

func _back() -> void:
	reset()
	get_tree().change_scene_to_packed(main_scene)

func _open_camera() -> void:
	if camera_helper.permission_granted():
		start_camera()
	else:
		camera_helper.request_permission()

func _permission_result(granted: bool) -> void:
	if granted:
		start_camera()
	else:
		permission_dialog.popup_centered()

func _camera_frame(image: MediaPipeImage) -> void:
	if not running_mode == MediaPipeTask.RUNNING_MODE_LIVE_STREAM:
		running_mode = MediaPipeTask.RUNNING_MODE_LIVE_STREAM
		init_task()
	if delegate == MediaPipeTaskBaseOptions.DELEGATE_CPU and image.is_gpu_image():
		image.convert_to_cpu()
	process_camera_frame(image, Time.get_ticks_msec())

func init_task() -> void:
	var base_options := MediaPipeTaskBaseOptions.new()
	base_options.delegate = delegate
	var file := FileAccess.open(task_file, FileAccess.READ)
	base_options.model_asset_buffer = file.get_buffer(file.get_length())
	task = MediaPipeHandLandmarker.new()
	task.initialize(base_options, running_mode, 2)
	task.result_callback.connect(self._result_callback)

func process_camera_frame(image: MediaPipeImage, timestamp_ms: int) -> void:
	task.detect_async(image, timestamp_ms)
	
func start_camera() -> void:
	reset()
	camera_helper.set_mirrored(false)
	camera_helper.start(cam_selection, Vector2(640, 480))

func reset() -> void:
	video_player.stop()
	camera_helper.close()

func update_image(image: Image) -> void:
	if Vector2i(image_view.texture.get_size()) == image.get_size():
		image_view.texture.call_deferred("update", image)
	else:
		image_view.texture.call_deferred("set_image", image)

func show_result(image: Image, result: MediaPipeHandLandmarkerResult) -> void:
	call_deferred("move_points", result)
	#for landmarks in result.hand_landmarks:
		#draw_landmarks(image, landmarks)
	#var handedness_text := ""
	#for categories in result.handedness:
		#for category in categories.categories:
			#handedness_text += "%s\n" % [category.display_name]
	##lbl_handedness.call_deferred("set_text", handedness_text)
	#update_image(image)

func draw_landmarks(image: Image, landmarks: MediaPipeNormalizedLandmarks) -> void:
	var color := Color.GREEN
	var rect := Image.create(4, 4, false, image.get_format())
	rect.fill(color)
	var image_size := Vector2(image.get_size())

	for landmark in landmarks.landmarks:
		var pos := Vector2(landmark.x, landmark.y)
		image.blit_rect(rect, rect.get_used_rect(), Vector2i(image_size * pos) - rect.get_size() / 2)

func move_points(result: MediaPipeHandLandmarkerResult) -> void:
	for i in range(len(result.hand_landmarks)):
		for hand in result.handedness[i].categories:
			if hand.display_name == "Left":
				var j = 0
				for k in result.hand_landmarks[i].landmarks:
					var point = lhand.get_child(j)
					j += 1
					point.global_transform.origin = Vector3(k.x*5-2.5,-k.y*5+2.5,k.z*5-2.5)
			elif hand.display_name == "Right":
				var j = 0
				for k in result.hand_landmarks[i].landmarks:
					var point = rhand.get_child(j)
					j += 1
					point.global_transform.origin = Vector3(k.x*5-2.5,-k.y*5+2.5,k.z*5-2.5)
