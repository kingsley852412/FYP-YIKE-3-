# FYP (YIKE 3)
HKUST FYP YIKE 3, programming game

Programming Game about basic programming/AI/Data analysis

uses customized programming language for user input

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