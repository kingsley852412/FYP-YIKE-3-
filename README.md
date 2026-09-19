# FYP (YIKE 3)
HKUST FYP YIKE 3, programming game

Programming Game about basic programming/AI/Data analysis

Players submit basic Python code and call the provided `robot` object. Each
submission runs in a fresh CPython worker process; players do not need any
third-party package. Imports are rejected.

## Python runtime

```python
for i in range(5):
    robot.move_right()
robot.move_down(4)
robot.rescue()
print(robot.position)
```

`robot.move_up/down/left/right(steps=1)` returns whether the requested movement
finished. `robot.can_move("up")` and the directional variants query the live
board. `robot.position` returns `(x, y)`. `robot.rescue()` returns true only
while standing on the target and opens the completion dialog.

Godot and Python use a local JSON Lines connection. Python waits for every game
API reply, so loops such as `while robot.can_move_right(): robot.move_right()`
always read the actual post-animation board state. Stop and Reset terminate the
worker and cancel delayed movement callbacks. The runtime limits source size,
Python steps, output, API calls, movement steps and elapsed time.

Development requires Python 3.10+ on PATH. To use a different interpreter, set
the `FYP_PYTHON` environment variable to its executable. For desktop export,
include `runtime/python_worker.py` as a non-resource file and distribute a full
CPython runtime in `runtime/python/` if Python is not already installed.

<h1> Class Diagram of a Level </h1>
<img src="documentation/Level class diagram.png" alt="Alt text" width="800"/>

<h2> Level </h2>
consist of UI/button/labels

has a Game_Map_Scene

calls functions of Game_Map_Scene to execute code/reset level/refresh Hint

<h2> Game_Map_Scene </h2>
purpose: to manage the 2D world that shows character/animations/etc.

also manages audio/animation/win condition checking

Has a Compiler for parsing/processing code,
recieving structured/formatted instruction from compiler to perform further tasks
(e.g. audio/animation/etc.,)

(I guess this class is gonna be the most large/complicated)

<h3> Game_Map_Scene_Level_1 </h3>
Inherits Game_Map_Scene,
Is the Game_Map_Scene for level 1

implements function for code execution/etc.

Future Plan: store level-specific info in inherited scene class (e.g. Hints, implementation of code execution/reset function, etc.)

<h2> Compiler </h2>
Recieves Raw, unprocessed code inputted by user (from Game_Map_Scene)
Returns List of instructions to Game_Map_Scene
(e.g. move_up, move_down, etc.)
<br></br>

<h1>Implementing Scene Transition</h1>
To switch among scene like:
<ul>
    <li>start menu</li>
    <li>level seletion menu</li>
    <li>different levels</li>
</ul>

we use a Global Autoload object, <b><i>SceneManager</i></b> to manage the transition

e.g.
functions like
<ul>
    <li>goto_start_menu()</li>
    <li>goto_level_seletion()</li>
    <li>goto_level()</li>
</ul>

are used by the scenes above to switch to other scenes.

<h1>usage of signals</h1>
<h2>GameMapScene to Level</h2>
level completion signal are broadcasted from GameMapScene, then recieved by Level (node).
<br></br>
it is used for showing level completion message (confirmation modal), and asking player to go to next level (or stay at the level)

<h2>ConfirmationModal to Level</h2>
after asking player to choose if they go to next level, a ConfirmationModal is shown.

it will send signal about player choice, then Level node can take corresponding action.

(call SceneManager/Hide ConfirmationModal)
