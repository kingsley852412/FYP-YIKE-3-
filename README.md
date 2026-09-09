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