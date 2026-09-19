class_name PythonRunner
extends Node
## A nonblocking, loopback-only JSON Lines bridge to a fresh CPython worker.

signal running_changed(running: bool)
signal output_received(text: String)
signal execution_failed(error: Dictionary)
signal execution_finished
signal execution_cancelled
signal call_requested(method: String, args: Array, request_id: int, generation: int)

const MAX_MESSAGE := 131072
const MAX_SOURCE := 16000
const MAX_OUTPUT := 16000
const MAX_REQUESTS := 2000

var python_executable := ""
var max_runtime_seconds := 60.0
var startup_timeout_seconds := 10.0
var max_steps := 100000
var is_running := false
var generation := 0
var _server: TCPServer
var _peer: StreamPeerTCP
var _pid := -1
var _worker_path := ""
var _source := ""
var _token := ""
var _authenticated := false
var _started_at := 0
var _input := PackedByteArray()
var _output := PackedByteArray()
var _printed := 0
var _requests := 0
var _pending_id := 0


func run_code(source: String) -> bool:
	if is_running:
		return false
	generation += 1
	is_running = true
	running_changed.emit(true)
	if source.strip_edges().is_empty():
		_fail("Please enter some Python code.")
		return false
	if source.to_utf8_buffer().size() > MAX_SOURCE:
		_fail("Code is too long (maximum 16 KB).")
		return false
	var executable := _find_python()
	if executable.is_empty():
		_fail("Python 3 was not found. Set FYP_PYTHON to its executable path; see README.")
		return false
	if not FileAccess.file_exists(executable):
		_fail("Could not start Python: executable path does not exist. Check FYP_PYTHON.")
		return false
	var worker_source := FileAccess.get_file_as_string("res://runtime/python_worker.py")
	if worker_source.is_empty():
		_fail("Python worker is missing. Include runtime/*.py in the export filters.")
		return false
	# Exported res:// may be inside a PCK; Python needs a real filesystem file.
	_token = Crypto.new().generate_random_bytes(24).hex_encode()
	_worker_path = "user://python_worker_%s_%s.py" % [OS.get_process_id(), _token.substr(0, 12)]
	var file := FileAccess.open(_worker_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not prepare the Python worker.")
		return false
	file.store_string(worker_source)
	file.close()
	_server = TCPServer.new()
	if _server.listen(0, "127.0.0.1") != OK:
		_fail("Could not open the local Python connection.")
		return false
	_source = source
	_started_at = Time.get_ticks_msec()
	_pid = OS.create_process(executable, PackedStringArray([
		"-I", "-u", ProjectSettings.globalize_path(_worker_path),
		str(_server.get_local_port()), _token,
	]), false)
	if _pid == -1:
		_fail("Could not start Python. Check FYP_PYTHON or interpreter/python_executable.")
		return false
	return true


func cancel() -> void:
	if is_running:
		_cleanup()
		execution_cancelled.emit()


func reply(request_id: int, run_generation: int, value: Variant = null, error := "") -> void:
	if not is_running or run_generation != generation or request_id != _pending_id:
		return
	_pending_id = 0
	var message := {"type": "result", "id": request_id}
	if error.is_empty():
		message["value"] = value
	else:
		message["error"] = error
	_queue(message)


func _process(_delta: float) -> void:
	if not is_running:
		return
	var elapsed := (Time.get_ticks_msec() - _started_at) / 1000.0
	var timeout := max_runtime_seconds if _authenticated else startup_timeout_seconds
	if elapsed > timeout:
		_fail("Execution timed out; check your loops." if _authenticated else "Python startup timed out. Check your Python executable.")
		return
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
		_peer.set_no_delay(true)
	if _peer == null:
		if _pid != -1 and not OS.is_process_running(_pid):
			_fail("Python exited before connecting. Python 3.10+ is required.")
		return
	_peer.poll()
	var available := _peer.get_available_bytes()
	if available > 0:
		var data := _peer.get_partial_data(mini(available, 65536))
		if data[0] != OK:
			_fail("Could not read from Python.")
			return
		_input.append_array(data[1])
		if _input.size() > MAX_MESSAGE:
			_fail("Python message is too large.")
			return
	for index in range(64):
		var newline := _input.find(10)
		if newline == -1:
			break
		var line := _input.slice(0, newline).get_string_from_utf8()
		_input = _input.slice(newline + 1)
		var message: Variant = JSON.parse_string(line)
		if not message is Dictionary:
			_fail("Invalid Python message.")
			return
		_handle_message(message)
		if not is_running or _peer == null:
			return
	if not _output.is_empty():
		var sent := _peer.put_partial_data(_output)
		if sent[0] != OK:
			_fail("Could not send to Python.")
			return
		_output = _output.slice(int(sent[1]))
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and _input.is_empty():
		_fail("Python disconnected before the program finished.")


func _handle_message(message: Dictionary) -> void:
	if not _authenticated:
		if message.get("type") != "hello" or message.get("token") != _token:
			_peer.disconnect_from_host()
			_peer = null
			_input.clear()
			return
		_authenticated = true
		_server.stop()
		_started_at = Time.get_ticks_msec()
		_queue({"type": "run", "source": _source, "max_steps": max_steps, "max_output": MAX_OUTPUT})
		return
	match message.get("type"):
		"call":
			_requests += 1
			if _pending_id != 0 or _requests > MAX_REQUESTS or int(message.get("id", 0)) != _requests:
				_fail("Invalid or excessive game API requests.")
				return
			if not message.get("method") is String or not message.get("args") is Array:
				_fail("Invalid game API arguments.")
				return
			_pending_id = _requests
			call_requested.emit(message["method"], message["args"], _pending_id, generation)
		"output":
			var content := str(message.get("text", ""))
			_printed += content.length()
			if _printed > MAX_OUTPUT:
				_fail("Output limit exceeded.")
			else:
				output_received.emit(content)
		"error":
			_cleanup()
			execution_failed.emit(message)
		"done":
			_cleanup()
			execution_finished.emit()
		_:
			_fail("Unknown Python message.")


func _queue(message: Dictionary) -> void:
	_output.append_array((JSON.stringify(message) + "\n").to_utf8_buffer())


func _fail(message: String) -> void:
	_cleanup()
	execution_failed.emit({"name": "ExecutionError", "message": message, "line": 0})


func _cleanup() -> void:
	generation += 1
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	if _server != null:
		_server.stop()
	_server = null
	if _pid != -1 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if not _worker_path.is_empty() and FileAccess.file_exists(_worker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_worker_path))
	_worker_path = ""
	_authenticated = false
	_source = ""
	_token = ""
	_input.clear()
	_output.clear()
	_pending_id = 0
	_requests = 0
	_printed = 0
	is_running = false
	running_changed.emit(false)


func _find_python() -> String:
	var configured := python_executable
	if configured.is_empty():
		configured = OS.get_environment("FYP_PYTHON")
	if configured.is_empty():
		configured = str(ProjectSettings.get_setting("interpreter/python_executable", ""))
	if not configured.is_empty():
		return ProjectSettings.globalize_path(configured)
	var windows := OS.get_name() == "Windows"
	var binary := "python.exe" if windows else "bin/python3"
	var base := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var bundled := base.path_join("runtime/python").path_join(binary)
	if FileAccess.file_exists(bundled):
		return bundled
	var names := ["python.exe"] if windows else ["python3", "python"]
	for directory in OS.get_environment("PATH").split(";" if windows else ":"):
		if windows and "windowsapps" in directory.to_lower():
			continue
		for name in names:
			var candidate := directory.trim_prefix('"').trim_suffix('"').path_join(name)
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


func _exit_tree() -> void:
	if is_running:
		_cleanup()
