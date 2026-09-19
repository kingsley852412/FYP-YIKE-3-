"""Exercise the real worker process and wire protocol, with a small fake game."""

from contextlib import contextmanager
import json
from pathlib import Path
import select
import socket
import subprocess
import sys
import unittest

WORKER = Path(__file__).resolve().parents[1] / "runtime" / "python_worker.py"


@contextmanager
def session(source, **limits):
    with socket.socket() as server:
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        server.settimeout(5)
        process = subprocess.Popen(
            [sys.executable, "-I", "-u", str(WORKER), str(server.getsockname()[1]), "test-token"],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        try:
            connection, _ = server.accept()
            with connection, connection.makefile("rb") as reader:
                connection.settimeout(5)

                def receive():
                    line = reader.readline()
                    if not line:
                        raise AssertionError("Worker disconnected unexpectedly")
                    return json.loads(line)

                def send(message):
                    connection.sendall((json.dumps(message) + "\n").encode())

                assert receive() == {"type": "hello", "token": "test-token"}
                send({"type": "run", "source": source, **limits})
                yield receive, send, connection
        finally:
            if process.poll() is None:
                process.kill()
            _, stderr = process.communicate(timeout=5)
            if stderr:
                raise AssertionError(stderr.decode())


def run_program(source, **limits):
    events = []
    position = [0, 0]
    directions = {"right": (1, 0), "left": (-1, 0), "up": (0, -1), "down": (0, 1)}
    with session(source, **limits) as (receive, send, _):
        while True:
            event = receive()
            events.append(event)
            if event["type"] == "call":
                method = event["method"]
                if method.startswith("robot.move_"):
                    dx, dy = directions[method.removeprefix("robot.move_")]
                    position[0] += dx * event["args"][0]
                    position[1] += dy * event["args"][0]
                    value = True
                elif method == "robot.position":
                    value = position
                elif method == "robot.can_move":
                    value = position[0] < 3
                else:
                    raise AssertionError(method)
                send({"type": "result", "id": event["id"], "value": value})
            elif event["type"] in ("done", "error"):
                send({"type": "close"})
                return events


class WorkerTests(unittest.TestCase):
    def test_python_basics_and_live_state(self):
        events = run_program("""
def advance():
    while robot.can_move_right():
        robot.move_right()
advance()
values = [i * i for i in range(4)]
assert sum(values) == 14
assert type(values) == list
assert {'x': robot.position[0]} == {'x': 3}
assert robot.position == (3, 0)
print('到达', robot.position)
""")
        self.assertEqual(events[-1]["type"], "done")
        self.assertEqual([e["text"] for e in events if e["type"] == "output"], ["到达 (3, 0)\n"])

    def test_functions_classes_and_exceptions(self):
        events = run_program("""
class Counter:
    def __init__(self, value):
        self.value = value
    def add(self):
        self.value += 1
c = Counter(2)
c.add()
try:
    1 / 0
except ZeroDivisionError:
    print(c.value)
""")
        self.assertEqual(events[-1]["type"], "done")
        self.assertEqual(events[0]["text"], "3\n")

    def test_imports_rejected_before_any_action(self):
        for source in ("robot.move_right()\nimport math", "from math import sqrt",
                       "if False:\n    import os"):
            with self.subTest(source=source):
                events = run_program(source)
                self.assertEqual(len(events), 1)
                self.assertEqual(events[0]["name"], "SyntaxError")
                self.assertGreater(events[0]["line"], 0)

    def test_runtime_and_syntax_error_lines(self):
        for source, name, line in (("x = 1\n1 / 0", "ZeroDivisionError", 2),
                                   ("for x in range(3)\n    pass", "SyntaxError", 1),
                                   ("def f():\n    missing\nf()", "NameError", 2)):
            with self.subTest(name=name):
                error = run_program(source)[-1]
                self.assertEqual((error["name"], error["line"]), (name, line))

    def test_unavailable_capabilities(self):
        for source in ("open('example.txt')", "eval('1+1')", "exec('pass')",
                       "__import__('math')", "robot._channel"):
            with self.subTest(source=source):
                self.assertEqual(run_program(source)[-1]["type"], "error")

    def test_invalid_api_arguments_and_names(self):
        for expression in ("robot.move_right(-1)", "robot.move_right(True)",
                           "robot.move_right(1.5)", "robot.move_right(101)",
                           "robot.can_move('diagonal')", "robot.teleport()"):
            with self.subTest(expression=expression):
                events = run_program(expression)
                self.assertEqual(len(events), 1)
                self.assertEqual(events[0]["type"], "error")

    def test_infinite_loops_and_output_are_bounded(self):
        for source in ("while True: pass", "while True:\n    pass"):
            error = run_program(source, max_steps=1000)[-1]
            self.assertEqual(error["name"], "ProgramLimit")
        error = run_program("print('x' * 101)", max_output=100)[-1]
        self.assertEqual(error["name"], "ProgramLimit")

    def test_worker_waits_for_action_acknowledgement(self):
        with session("robot.move_right()\nprint('after')") as (receive, send, connection):
            call = receive()
            self.assertEqual(call["type"], "call")
            self.assertFalse(select.select([connection], [], [], 0.1)[0])
            send({"type": "result", "id": call["id"], "value": True})
            self.assertEqual(receive(), {"type": "output", "text": "after\n"})
            self.assertEqual(receive()["type"], "done")
            send({"type": "close"})

    def test_game_errors_become_python_exceptions(self):
        with session("robot.move_right()") as (receive, send, _):
            call = receive()
            send({"type": "result", "id": call["id"], "error": "Movement limit exceeded"})
            error = receive()
            self.assertEqual((error["name"], error["line"]), ("RuntimeError", 1))
            send({"type": "close"})

    def test_new_process_has_no_old_variables(self):
        self.assertEqual(run_program("secret = 42")[-1]["type"], "done")
        self.assertEqual(run_program("print(secret)")[-1]["name"], "NameError")


if __name__ == "__main__":
    unittest.main()
