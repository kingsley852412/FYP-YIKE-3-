extends CodeEdit
## Python editing support. The text remains ordinary source for the CPython worker.

const KEYWORD_COLOR := Color("c586c0")
const BUILTIN_COLOR := Color("4ec9b0")
const STRING_COLOR := Color("ce9178")
const COMMENT_COLOR := Color("82a66b")
const NUMBER_COLOR := Color("b5cea8")
const FUNCTION_COLOR := Color("dcdcaa")
const SYMBOL_COLOR := Color("d4d4d4")
const MEMBER_COLOR := Color("9cdcfe")

const KEYWORDS := [
	"False", "None", "True", "and", "as", "assert", "async", "await", "break",
	"class", "continue", "def", "del", "elif", "else", "except", "finally",
	"for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
	"not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
	"match", "case",
]
const BUILTINS := [
	"abs", "all", "any", "bin", "bool", "bytes", "bytearray", "callable", "chr",
	"dict", "divmod", "enumerate", "filter", "float", "format", "frozenset",
	"hex", "int", "isinstance", "issubclass", "iter", "len", "list", "map",
	"max", "min", "next", "object", "oct", "ord", "pow", "print", "property",
	"range", "repr", "reversed", "round", "set", "slice", "sorted", "str",
	"sum", "super", "tuple", "type", "zip", "Exception", "ValueError",
	"TypeError", "RuntimeError", "ZeroDivisionError", "robot",
]


func _ready() -> void:
	indent_size = 4
	indent_use_spaces = true
	indent_automatic = true
	indent_automatic_prefixes = [":", "(", "[", "{"]
	gutters_draw_line_numbers = true
	gutters_line_numbers_min_digits = 2
	highlight_current_line = true
	draw_tabs = true
	clear_string_delimiters()
	add_string_delimiter('"""', '"""')
	add_string_delimiter("'''", "'''")
	add_string_delimiter('"', '"', true)
	add_string_delimiter("'", "'", true)
	clear_comment_delimiters()
	add_comment_delimiter("#", "", true)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono"])
	add_theme_font_override("font", font)

	var highlighter := CodeHighlighter.new()
	highlighter.number_color = NUMBER_COLOR
	highlighter.function_color = FUNCTION_COLOR
	highlighter.symbol_color = SYMBOL_COLOR
	highlighter.member_variable_color = MEMBER_COLOR
	for keyword in KEYWORDS:
		highlighter.add_keyword_color(keyword, KEYWORD_COLOR)
	for builtin in BUILTINS:
		highlighter.add_keyword_color(builtin, BUILTIN_COLOR)
	highlighter.add_color_region('"""', '"""', STRING_COLOR)
	highlighter.add_color_region("'''", "'''", STRING_COLOR)
	highlighter.add_color_region('"', '"', STRING_COLOR, true)
	highlighter.add_color_region("'", "'", STRING_COLOR, true)
	highlighter.add_color_region("#", "", COMMENT_COLOR, true)
	syntax_highlighter = highlighter
