"""One player program per process. Standard library only; not a security sandbox."""

import ast
import builtins
import json
import socket
import sys
import traceback

PLAYER_FILE = "<player>"
MAX_MESSAGE = 131072


class ProgramLimit(BaseException):
    pass


class Channel:
    def __init__(self, connection):
        self.connection = connection
        self.reader = connection.makefile("rb")
        self.request_id = 0

    def send(self, message):
        data = (json.dumps(message, ensure_ascii=True, allow_nan=False) + "\n").encode()
        if len(data) > MAX_MESSAGE:
            raise ProgramLimit("Message is too large")
        self.connection.sendall(data)

    def receive(self):
        line = self.reader.readline(MAX_MESSAGE + 1)
        if not line or len(line) > MAX_MESSAGE or not line.endswith(b"\n"):
            raise ConnectionError("Game connection closed or message too large")
        return json.loads(line)

    def call(self, method, args):
        self.request_id += 1
        self.send({"type": "call", "id": self.request_id, "method": method, "args": args})
        response = self.receive()
        if response.get("type") != "result" or response.get("id") != self.request_id:
            raise ConnectionError("Unexpected game response")
        if "error" in response:
            raise RuntimeError(response["error"])
        return response.get("value")


class Robot:
    def __init__(self, channel):
        self._channel = channel

    def _move(self, direction, steps):
        if type(steps) is not int:
            raise TypeError("steps must be an integer")
        if not 0 <= steps <= 100:
            raise ValueError("steps must be between 0 and 100")
        return self._channel.call("robot.move_" + direction, [steps])

    def move_up(self, steps=1):
        return self._move("up", steps)

    def move_down(self, steps=1):
        return self._move("down", steps)

    def move_left(self, steps=1):
        return self._move("left", steps)

    def move_right(self, steps=1):
        return self._move("right", steps)

    def can_move(self, direction):
        if direction not in ("up", "down", "left", "right"):
            raise ValueError("direction must be up, down, left, or right")
        return self._channel.call("robot.can_move", [direction])

    def can_move_up(self):
        return self.can_move("up")

    def can_move_down(self):
        return self.can_move("down")

    def can_move_left(self):
        return self.can_move("left")

    def can_move_right(self):
        return self.can_move("right")

    def rescue(self):
        return self._channel.call("robot.rescue", [])

    @property
    def position(self):
        return tuple(self._channel.call("robot.position", []))


def check_source(source):
    if not source.strip():
        raise SyntaxError("Please enter some Python code")
    tree = ast.parse(source, filename=PLAYER_FILE)
    for node in ast.walk(tree):
        message = None
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            message = "Imports are not available. Use Python basics and robot instead."
        elif isinstance(node, ast.Attribute) and node.attr.startswith("_"):
            message = "Private attributes are not available."
        elif isinstance(node, ast.Name) and node.id.startswith("__"):
            message = "Internal names are not available."
        if message:
            raise SyntaxError(message, (PLAYER_FILE, node.lineno, node.col_offset + 1,
                                        source.splitlines()[node.lineno - 1]))
    return compile(tree, PLAYER_FILE, "exec")


def execute(source, channel, max_steps=100000, max_output=16000):
    output_count = 0
    steps = 0

    def player_print(*values, sep=" ", end="\n", flush=False):
        nonlocal output_count
        if sep is None:
            sep = " "
        if end is None:
            end = "\n"
        if not isinstance(sep, str) or not isinstance(end, str):
            raise TypeError("sep and end must be strings")
        text = sep.join(str(value) for value in values) + end
        output_count += len(text)
        if output_count > max_output:
            raise ProgramLimit("Output limit exceeded")
        if text:
            channel.send({"type": "output", "text": text})

    def trace(frame, event, arg):
        nonlocal steps
        if frame.f_code.co_filename == PLAYER_FILE:
            # Opcode events also count one-line loops and expressions.
            frame.f_trace_opcodes = True
            if event == "opcode":
                steps += 1
                if steps > max_steps:
                    raise ProgramLimit("Execution step limit exceeded; check your loops")
        return trace

    names = """
        abs all any bin bool chr dict divmod enumerate filter float format frozenset
        hex int isinstance issubclass iter len list map max min next oct ord pow
        range repr reversed round set slice sorted str sum tuple type callable zip
        object property staticmethod classmethod super __build_class__
        Exception ArithmeticError AssertionError AttributeError IndexError KeyError
        LookupError NameError NotImplementedError OverflowError RuntimeError
        StopIteration TypeError ValueError ZeroDivisionError
    """.split()
    allowed = {name: getattr(builtins, name) for name in names}
    allowed["print"] = player_print
    namespace = {"__builtins__": allowed, "__name__": "__player__", "robot": Robot(channel)}
    try:
        program = check_source(source)
        sys.settrace(trace)
        exec(program, namespace, namespace)
    finally:
        sys.settrace(None)


def error_details(error):
    if isinstance(error, SyntaxError):
        line, column = error.lineno or 0, error.offset or 0
        message = error.msg
    else:
        frames = [frame for frame in traceback.extract_tb(error.__traceback__)
                  if frame.filename == PLAYER_FILE]
        line = frames[-1].lineno if frames else 0
        column = 0
        message = str(error)
    return {"type": "error", "name": type(error).__name__, "message": message[:2000],
            "line": line, "column": column}


def main():
    port, token = int(sys.argv[1]), sys.argv[2]
    with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
        connection.settimeout(None)
        channel = Channel(connection)
        channel.send({"type": "hello", "token": token})
        request = channel.receive()
        if request.get("type") != "run":
            return
        try:
            execute(request["source"], channel, request.get("max_steps", 100000),
                    request.get("max_output", 16000))
        except BaseException as error:
            channel.send(error_details(error))
        else:
            channel.send({"type": "done"})
        # Wait until Godot has consumed the terminal message before exiting.
        try:
            channel.receive()
        except (ConnectionError, OSError):
            pass


if __name__ == "__main__":
    main()
