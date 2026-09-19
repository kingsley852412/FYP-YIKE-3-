extends SceneTree
## Run with: godot --headless --path . --script tests/test_game_runtime.gd

var failures := 0
var level: Control
var game: GameMapScene


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func wait_for_finish() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while game.compiler.is_running and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.compiler.is_running, "program finished within test deadline")
	if game.compiler.is_running:
		game.stop_code()


func submit(source: String) -> void:
	level.code_text_edit.text = source
	level.submit_button.pressed.emit()
	await wait_for_finish()


func wait_for_movement() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while game.robot_api.steps_used == 0 and game.compiler.is_running and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.robot_api.steps_used > 0, "movement entered its await")


func _run() -> void:
	level = load("res://level.tscn").instantiate()
	root.add_child(level)
	await process_frame
	game = level.game_map_scene
	game.mc_body.movement_delay = 0.01
	await submit(level.code_text_edit.text)
	check(game.mc_body.get_cell() == Vector2i(5, 4), "default program reaches target")
	check(level.output_text.text == "(5, 4)\n", "Python output reaches UI")
	check(not level.submit_button.disabled and level.stop_button.disabled, "buttons restored after success")

	game.level_reset()
	await submit("robot.move_right()\nimport math")
	check(game.mc_body.get_cell() == Vector2i.ZERO, "imports rejected before side effects")
	check("Line 2:" in level.hint_label.text, "error line displayed")
	check(level.code_text_edit.get_selected_text() == "import math", "error source selected")
	await submit("print('你好')\n1 / 0")
	check(level.output_text.text == "你好\n", "Unicode output survives transport")
	check("ZeroDivisionError" in level.hint_label.text, "runtime error displayed")

	await submit("while robot.position[0] < 2:\n    assert robot.can_move_right()\n    robot.move_right()")
	check(game.mc_body.get_cell() == Vector2i(2, 0), "conditions query state after movement")
	await submit("while True: pass")
	check("step limit" in level.hint_label.text, "one-line infinite loop stopped")
	await submit("print('x' * 16001)")
	check("Output limit" in level.hint_label.text, "print output bounded")
	var unknown: Dictionary = await game.robot_api.dispatch("robot.queue_free", [])
	check(unknown.has("error"), "adapter only exposes explicitly registered methods")
	game.robot_api.steps_used = 100
	var exhausted: Dictionary = await game.robot_api.dispatch("robot.move_right", [1])
	check(exhausted.has("error"), "Godot enforces its own movement budget")
	for direction in game.robot_api.DIRECTIONS:
		if not game.mc_body.can_move(game.robot_api.DIRECTIONS[direction]):
			var old_cell: Vector2i = game.mc_body.get_cell()
			await submit("print(robot.move_%s())" % direction)
			check(level.output_text.text == "False\n" and game.mc_body.get_cell() == old_cell, "blocked movement returns False")
			break

	# Reset while an action sleeps, then start a new program before it wakes.
	game.level_reset()
	game.mc_body.movement_delay = 0.3
	game.execute_code("robot.move_right(5)")
	var first_generation: int = game.compiler.generation
	game.execute_code("robot.move_down()")
	check(game.compiler.generation == first_generation, "duplicate submission ignored")
	await wait_for_movement()
	level.reset_button.pressed.emit()
	game.mc_body.movement_delay = 0.01
	await submit("robot.move_right()")
	await create_timer(0.4).timeout
	check(game.mc_body.get_cell() == Vector2i(1, 0), "old movement cannot change new run")

	game.level_reset()
	game.mc_body.movement_delay = 0.3
	game.execute_code("robot.move_right(5)")
	await wait_for_movement()
	level.stop_button.pressed.emit()
	await create_timer(0.4).timeout
	check(game.mc_body.get_cell() == Vector2i.ZERO, "Stop cancels pending movement")
	check(not game.compiler.is_running, "Stop terminates worker")

	# Host deadline remains effective even if player catches a trace-limit exception.
	game.compiler.max_runtime_seconds = 0.2
	await submit("try:\n    while True: pass\nexcept:\n    while True: pass")
	check("timed out" in level.hint_label.text, "host kills stuck worker")
	await submit("robot.move_right(5)")
	await create_timer(0.4).timeout
	check(game.mc_body.get_cell() == Vector2i.ZERO, "timeout cancels sleeping action")
	game.compiler.max_runtime_seconds = 60.0
	game.mc_body.movement_delay = 0.01
	await submit("robot.move_right()\nprint('recovered')")
	check(level.output_text.text == "recovered\n", "new program works after cancellation and timeout")

	await submit("   ")
	check("enter some Python" in level.hint_label.text, "empty input handled")
	check(not level.submit_button.disabled, "invalid input does not lock Submit")
	game.compiler.python_executable = "S:/missing-fyp-python/python.exe"
	await submit("pass")
	check("Could not start Python" in level.hint_label.text, "startup failure shown")
	game.compiler.python_executable = ""
	game.execute_code("robot.move_right(5)")
	await wait_for_movement()
	var worker_pid: int = game.compiler._pid
	level.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	check(not OS.is_process_running(worker_pid), "leaving the scene terminates its worker")
	print("Game runtime tests: %d failures" % failures)
	quit(1 if failures else 0)
