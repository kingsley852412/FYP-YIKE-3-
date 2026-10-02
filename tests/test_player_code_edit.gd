extends SceneTree
## Tests real editor input and the level integration; no Python syntax reimplementation.

var failures := 0
var editor: CodeEdit
var level: Control


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func prepare(text: String) -> void:
	editor.deselect()
	editor.text = text
	editor.set_caret_line(editor.get_line_count() - 1)
	editor.set_caret_column(editor.get_line(editor.get_caret_line()).length())
	editor.grab_focus()
	await process_frame


func action(name: String) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER if name == "ui_text_newline" else KEY_TAB
	event.shift_pressed = name == "ui_text_dedent"
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)


func color_at(line: int, column: int) -> Color:
	var segments := editor.syntax_highlighter.get_line_syntax_highlighting(line)
	var offsets := segments.keys()
	offsets.sort()
	var color := editor.get_theme_color("font_color")
	for offset in offsets:
		if offset > column:
			break
		color = segments[offset]["color"]
	return color


func _run() -> void:
	level = load("res://level.tscn").instantiate()
	root.add_child(level)
	await process_frame
	editor = level.code_text_edit
	check(editor is CodeEdit, "scene uses code editor")
	check(editor.gutters_draw_line_numbers, "line numbers enabled")

	await prepare("for i in range(3): # repeat")
	check(color_at(0, 0) == editor.KEYWORD_COLOR, "Python keyword highlighted")
	check(color_at(0, 9) == editor.BUILTIN_COLOR, "builtin highlighted")
	check(color_at(0, 15) == editor.NUMBER_COLOR, "number highlighted")
	check(color_at(0, 19) == editor.COMMENT_COLOR, "comment highlighted")
	await action("ui_text_newline")
	check(editor.text == "for i in range(3): # repeat\n    ", "Enter indents block after inline comment")
	check(editor.get_caret_column() == 4, "caret after four spaces")
	await action("ui_text_indent")
	check(editor.get_line(1) == "        ", "Tab adds four spaces")
	await action("ui_text_dedent")
	check(editor.get_line(1) == "    ", "Shift+Tab removes one indent")
	check(not "\t" in editor.text, "indentation uses spaces")

	await prepare("    robot.move_right()")
	await action("ui_text_newline")
	check(editor.get_line(1) == "    ", "Enter preserves existing indentation")
	await prepare("if True:\n    for i in range(2):")
	await action("ui_text_newline")
	check(editor.get_line(2) == "        ", "nested block gets eight spaces")
	await prepare("values = [")
	await action("ui_text_newline")
	check(editor.get_line(1) == "    ", "open bracket indents continuation line")
	await prepare("message = 'if: # string'")
	check(color_at(0, 11) == editor.STRING_COLOR, "keywords and comments inside string stay string-colored")
	await action("ui_text_newline")
	check(editor.get_line(1).is_empty(), "colon inside string does not indent")
	await prepare("# if True:")
	await action("ui_text_newline")
	check(editor.get_line(1).is_empty(), "colon inside comment does not indent")
	await prepare('message = """first\n# second\nlast"""\nx = 2')
	check(color_at(1, 0) == editor.STRING_COLOR, "triple-quoted string carries across lines")
	check(color_at(3, 4) == editor.NUMBER_COLOR, "highlighting resumes after triple-quoted string")

	await prepare("robot.move_right()\nrobot.move_down()")
	editor.select(0, 0, 1, editor.get_line(1).length())
	await action("ui_text_indent")
	check(editor.get_line(0).begins_with("    ") and editor.get_line(1).begins_with("    "), "Tab indents selected lines")
	await action("ui_text_dedent")
	check(editor.text == "robot.move_right()\nrobot.move_down()", "Shift+Tab dedents selected lines")
	editor.deselect()
	editor.undo()
	check(editor.get_line(0).begins_with("    "), "indent changes participate in undo")

	level._on_execution_state_changed(true)
	var before := editor.text
	await action("ui_text_newline")
	check(editor.text == before and not editor.editable, "running lock prevents editor changes")
	level._on_execution_state_changed(false)
	level.reset_code_input(1)
	check(editor.text == level.DEFAULT_CODE_TEXT[1].replace("\r\n", "\n"), "Reset Code preserves default source")
	check(editor.syntax_highlighter != null, "Reset Code keeps highlighting")
	level._on_code_error(2)
	check(editor.get_selected_text() == "    robot.move_right()", "error-line selection works with CodeEdit")

	# Submit pure Python through the actual worker to check source and output wiring.
	editor.text = "print(sum([i for i in range(4)]))"
	level.submit_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 5000
	while level.game_map_scene.compiler.is_running and Time.get_ticks_msec() < deadline:
		await process_frame
	check(level.output_text.text == "6\n", "CodeEdit source executes through existing Python bridge")
	check(editor.editable, "execution restores editing")
	level.queue_free()
	await process_frame
	print("Player code editor tests: %d failures" % failures)
	quit(1 if failures else 0)
