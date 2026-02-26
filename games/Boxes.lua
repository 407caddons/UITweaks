local addonName, addonTable = ...
addonTable.Boxes = {}

-- ============================================================
-- Boxes — a Sokoban clone
-- Player texture: player portrait (unit model portrait)
-- Keybindings: shared LunaUITweaks game keybinds
--   Left  = LUNAUITWEAKS_GAME_LEFT
--   Right = LUNAUITWEAKS_GAME_RIGHT
--   Up    = LUNAUITWEAKS_GAME_ROTATECW
--   Down  = LUNAUITWEAKS_GAME_ROTATECCW
--   Pause = LUNAUITWEAKS_GAME_PAUSE  (used for Undo here)
-- ============================================================

-- ============================================================
-- Level data
-- # = wall   @ = player   $ = box   . = goal
-- * = box on goal          + = player on goal
-- ============================================================
local LEVELS = {
    -- 1  boxes=1 goals=1
    {
        name = "First Step",
        map = {
            "#####",
            "#.  #",
            "# $ #",
            "#  @#",
            "#####",
        }
    },
    -- 2  boxes=1 goals=1
    {
        name = "Push Right",
        map = {
            "######",
            "#    #",
            "# @$.#",
            "#    #",
            "######",
        }
    },
    -- 3  boxes=2 goals=2
    {
        name = "Two Goals",
        map = {
            "######",
            "#@   #",
            "# $  #",
            "# $  #",
            "# .. #",
            "######",
        }
    },
    -- 4  boxes=1 goals=1
    {
        name = "Corner",
        map = {
            "#####",
            "#.  #",
            "#   #",
            "# $ #",
            "## @#",
            " ####",
        }
    },
    -- 5  boxes=2 goals=2
    {
        name = "Around",
        map = {
            "#######",
            "#     #",
            "# $@$ #",
            "#     #",
            "#.   .#",
            "#######",
        }
    },
    -- 6  boxes=1 goals=1
    {
        name = "Shelf",
        map = {
            "######",
            "#    #",
            "# @$ #",
            "####.#",
            "   # #",
            "   ###",
        }
    },
    -- 7  boxes=2 goals=2
    {
        name = "Alley",
        map = {
            "  #####",
            "  #   #",
            "###$  #",
            "#  $. #",
            "# @.  #",
            "#######",
        }
    },
    -- 8  boxes=2 goals=2
    {
        name = "The L",
        map = {
            "#######",
            "#     #",
            "#  @$ #",
            "#  $  #",
            "#..   #",
            "#######",
        }
    },
    -- 9  boxes=2 goals=2
    {
        name = "Stagger",
        map = {
            "#######",
            "#  @  #",
            "# $ $ #",
            "## # ##",
            "#.   .#",
            "#######",
        }
    },
    -- 10  boxes=3 goals=3
    {
        name = "Depot",
        map = {
            "  #####  ",
            "###   ###",
            "# $ $ $ #",
            "#  ...  #",
            "#   @   #",
            "#########",
        }
    },
    -- 11  boxes=2 goals=2
    {
        name = "Pillars",
        map = {
            "#########",
            "#   @   #",
            "# $ # $ #",
            "#   #   #",
            "# .   . #",
            "#########",
        }
    },
    -- 12  boxes=2 goals=2
    {
        name = "Corridor",
        map = {
            "#######",
            "#     #",
            "# $.$ #",
            "# #.# #",
            "#  @  #",
            "#######",
        }
    },
    -- 13  boxes=2 goals=2
    {
        name = "Nook",
        map = {
            "######",
            "#    #",
            "# @$ #",
            "#  $ #",
            "#. .##",
            "#####",
        }
    },
    -- 14  boxes=2 goals=2
    {
        name = "Squeeze",
        map = {
            " ######",
            " # @  #",
            "##$   #",
            "#  ##.#",
            "#     #",
            "#  .$ #",
            "#######",
        }
    },
    -- 15  boxes=2 goals=2
    {
        name = "Island",
        map = {
            "#########",
            "#   #   #",
            "# $ # $ #",
            "#  ###  #",
            "# . @ . #",
            "#       #",
            "#########",
        }
    },
    -- 16  boxes=2 goals=2
    {
        name = "Zigzag",
        map = {
            "########",
            "#  @   #",
            "## ##$ #",
            " #  .  #",
            " # $ # #",
            " ##.   #",
            "  ######",
        }
    },
    -- 17  boxes=4 goals=4
    {
        name = "Pockets",
        map = {
            "#######",
            "#.$ $.#",
            "#     #",
            "#  @  #",
            "#     #",
            "#.$ $.#",
            "#######",
        }
    },
    -- 18  boxes=2 goals=2
    {
        name = "Inlet",
        map = {
            "########",
            "#      #",
            "#.$ #  #",
            "#   #  #",
            "#.$ #@##",
            "#   #  #",
            "########",
        }
    },
    -- 19  boxes=2 goals=2
    {
        name = "Bookends",
        map = {
            "#######",
            "#.    #",
            "#. $$ #",
            "##  ###",
            " # @#  ",
            " #  #  ",
            " ####  ",
        }
    },
    -- 20  boxes=3 goals=3
    {
        name = "Hallway",
        map = {
            " ######",
            "##    #",
            "#  $  #",
            "# .$  #",
            "##$#. #",
            " #    #",
            " # @. #",
            " ######",
        }
    },
    -- 21  boxes=3 goals=3
    {
        name = "Deadend",
        map = {
            " ######",
            "##    #",
            "#   $ #",
            "# $.$ #",
            "## .# #",
            " # .@ #",
            " ######",
        }
    },
    -- 22  boxes=2 goals=2
    {
        name = "Bypass",
        map = {
            "#######",
            "#     #",
            "# @ $ #",
            "#.#####",
            "#     #",
            "#   $ #",
            "#.    #",
            "#######",
        }
    },
    -- 23  boxes=4 goals=4
    {
        name = "Caterpillar",
        map = {
            "##########",
            "#        #",
            "# $.$.$. #",
            "#  @     #",
            "##########",
        }
    },
    -- 24  boxes=2 goals=2
    {
        name = "The Well",
        map = {
            "#######",
            "#     #",
            "#.###.#",
            "# # # #",
            "# $@$ #",
            "#     #",
            "#######",
        }
    },
    -- 25  boxes=4 goals=4
    {
        name = "Staircase",
        map = {
            "##########",
            "#  @     #",
            "# $ .    #",
            "#   . $  #",
            "#   .    #",
            "#   . $  #",
            "#        #",
            "#     $  #",
            "##########",
        }
    },
    -- 26  boxes=2 goals=2
    {
        name = "Maze",
        map = {
            "#########",
            "#   #   #",
            "# $ # $ #",
            "# #   # #",
            "#   #   #",
            "# . @ . #",
            "#########",
        }
    },
    -- 27  boxes=4 goals=4
    {
        name = "Bottleneck",
        map = {
            "####  ",
            "#  ###",
            "#  $.#",
            "## $.#",
            " #@$.#",
            " # $.#",
            " #   #",
            " #####",
        }
    },
    -- 28  boxes=3 goals=3
    {
        name = "Indent",
        map = {
            "########",
            "#  @   #",
            "# $$$  #",
            "##   ###",
            " #...#  ",
            " #####  ",
        }
    },
    -- 29  boxes=3 goals=3
    {
        name = "Stepping Stones",
        map = {
            "##########",
            "#        #",
            "# $#$#$# #",
            "#  . . . #",
            "#   @    #",
            "##########",
        }
    },
    -- 30  boxes=3 goals=3
    {
        name = "Warehouse",
        map = {
            "  #####  ",
            "  #   #  ",
            "  # $ #  ",
            "### $ ###",
            "#  .$. ##",
            "## $.$ ##",
            " # .@. # ",
            " #     # ",
            " ####### ",
        }
    },
    -- 31  boxes=4 goals=4
    {
        name = "Relay",
        map = {
            "##########",
            "#        #",
            "# $.$.$. #",
            "# ###### #",
            "#   @    #",
            "##########",
        }
    },
    -- 32  boxes=3 goals=3
    {
        name = "Arrow",
        map = {
            "  ###  ",
            "###.###",
            "#   .  #",
            "# $$$@ #",
            "#   .  #",
            "###  ###",
            "  ###  ",
        }
    },
    -- 33  boxes=2 goals=2
    {
        name = "Pinball",
        map = {
            "  ######",
            "###    #",
            "#   ## #",
            "#  $   #",
            "## $@. #",
            " #  .  #",
            " #######",
        }
    },
    -- 34  boxes=2 goals=2
    {
        name = "Tee",
        map = {
            " ########",
            " #  @   #",
            " # $ $  #",
            "## # #  #",
            "#  . .  #",
            "#       #",
            "#########",
        }
    },
    -- 35  boxes=3 goals=3
    {
        name = "Sidetrack",
        map = {
            " ######",
            "##    #",
            "#   $ #",
            "#  $  #",
            "## .$ #",
            " #  . #",
            " #  . #",
            " # @###",
            " ####  ",
        }
    },
    -- 36  boxes=2 goals=2
    {
        name = "The Gate",
        map = {
            "########",
            "#      #",
            "# $ $  #",
            "#  .@. #",
            "#  # # #",
            "########",
        }
    },
    -- 37  boxes=3 goals=3
    {
        name = "Overhang",
        map = {
            " #######",
            "##     #",
            "#  $$  #",
            "#  ..  #",
            "##   ###",
            " # $   #",
            " #  .@ #",
            " #######",
        }
    },
    -- 38  boxes=3 goals=3
    {
        name = "Wedge",
        map = {
            "  ######",
            "###    #",
            "#    $ #",
            "## $#  #",
            " #  $. #",
            " ## .  #",
            "  # .@ #",
            "  ######",
        }
    },
    -- 39  boxes=2 goals=2
    {
        name = "Roundabout",
        map = {
            " ########",
            "##       #",
            "# $ @  $ #",
            "#  #  #  #",
            "# .    . #",
            "##########",
        }
    },
    -- 40  boxes=2 goals=2
    {
        name = "Tripwire",
        map = {
            "#######",
            "#     #",
            "# $ . #",
            "## ## #",
            " # $. #",
            " # @  #",
            " ######",
        }
    },
    -- 41  boxes=4 goals=4
    {
        name = "Classic I",
        map = {
            "#######",
            "#     #",
            "#     #",
            "#. #  #",
            "#. $$ #",
            "#.$$  #",
            "#.#  @#",
            "#######",
        }
    },
    -- 42  boxes=4 goals=4
    {
        name = "Carousel",
        map = {
            " #######",
            "##  @  ##",
            "#  $$   #",
            "# .  .  #",
            "#  $$   #",
            "# .  .  #",
            "#########",
        }
    },
    -- 43  boxes=3 goals=3
    {
        name = "Barricade",
        map = {
            "  #####",
            "###   #",
            "#   $ #",
            "#  $  #",
            "## .$ #",
            " # @. #",
            " # .  #",
            " ######",
        }
    },
    -- 44  boxes=4 goals=4
    {
        name = "Crisscross",
        map = {
            "#########",
            "#   @   #",
            "#.$ # $.#",
            "# # # # #",
            "#.$ # $.#",
            "#   #   #",
            "#########",
        }
    },
    -- 45  boxes=2 goals=2
    {
        name = "Tributary",
        map = {
            "########",
            "#  .   #",
            "#  ##  #",
            "#   $  #",
            "## $#@ #",
            " #  .  #",
            " #######",
        }
    },
    -- 46  boxes=4 goals=4
    {
        name = "Lattice",
        map = {
            "#########",
            "#   @   #",
            "# $   $ #",
            "#   #   #",
            "# $   $ #",
            "#.#   #.#",
            "#  . .  #",
            "#########",
        }
    },
    -- 47  boxes=4 goals=4
    {
        name = "Bracket",
        map = {
            "########",
            "#.     #",
            "#. $$  #",
            "#.     #",
            "#. $$  #",
            "#   @  #",
            "########",
        }
    },
    -- 48  boxes=4 goals=4
    {
        name = "Prong",
        map = {
            "########",
            "#  . . #",
            "#  # # #",
            "#  $ $ #",
            "#   @  #",
            "#  $ $ #",
            "#  . . #",
            "########",
        }
    },
    -- 49  boxes=3 goals=3
    {
        name = "Keyhole",
        map = {
            " ######",
            "##    ##",
            "# .$. ##",
            "# $@$  #",
            "#  .   #",
            "##    ##",
            " ######",
        }
    },
    -- 50  boxes=4 goals=4
    {
        name = "Midway",
        map = {
            "##########",
            "#   @    #",
            "# $$ $$  #",
            "##  .... #",
            "##########",
        }
    },
    -- 51  boxes=2 goals=2
    {
        name = "Switchback",
        map = {
            "  #####",
            "###   #",
            "#   # #",
            "#  $  #",
            "## $@ #",
            " #  . #",
            " ##.  #",
            "  #####",
        }
    },
    -- 52  boxes=4 goals=4
    {
        name = "Tandem",
        map = {
            "########",
            "# .  . #",
            "# #  # #",
            "# $  $ #",
            "# #  # #",
            "# $  $ #",
            "#  @   #",
            "##.  .##",
        }
    },
    -- 53  boxes=3 goals=3
    {
        name = "Detour",
        map = {
            " ########",
            " #  @   #",
            "##  ##  #",
            "#.$ ##  #",
            "#   ## ##",
            "#.$ $  ##",
            "#.   ###",
            "######",
        }
    },
    -- 54  boxes=3 goals=3
    {
        name = "Offset",
        map = {
            "#######",
            "#     #",
            "# $.  #",
            "##.$  #",
            " #. $ #",
            " #  @ #",
            " ######",
        }
    },
    -- 55  boxes=2 goals=2
    {
        name = "Outpost",
        map = {
            "#########",
            "#   @   #",
            "#  $#$  #",
            "# #   # #",
            "# #.#.# #",
            "#   #   #",
            "#########",
        }
    },
    -- 56  boxes=3 goals=3
    {
        name = "Scaffold",
        map = {
            " ######",
            "##    #",
            "#   $ #",
            "#  $  #",
            "##$.  #",
            " # .@ #",
            " # .  #",
            " ######",
        }
    },
    -- 57  boxes=4 goals=4
    {
        name = "Leapfrog",
        map = {
            "##########",
            "#        #",
            "# $  $   #",
            "# $  $   #",
            "# ....   #",
            "#    @   #",
            "##########",
        }
    },
    -- 58  boxes=5 goals=5
    {
        name = "Spiral",
        map = {
            "#########",
            "#       #",
            "#@$$$$$ #",
            "# ..... #",
            "#########",
        }
    },
    -- 59  boxes=4 goals=4
    {
        name = "Crescent",
        map = {
            " ######",
            "##    #",
            "# $ $ #",
            "# . . #",
            "# $@$ #",
            "# . . #",
            "## ####",
            " ###",
        }
    },
    -- 60  boxes=2 goals=2
    {
        name = "Passage",
        map = {
            "  ####",
            "###  #",
            "# $  #",
            "# .@ #",
            "## $ #",
            " # . #",
            " #   #",
            " #####",
        }
    },
    -- 61  boxes=2 goals=2
    {
        name = "Blockade",
        map = {
            "########",
            "#  @   #",
            "#  $$  #",
            "# #  # #",
            "# #..# #",
            "#      #",
            "########",
        }
    },
    -- 62  boxes=2 goals=2
    {
        name = "The Pit",
        map = {
            "#########",
            "#   #   #",
            "# $ # $ #",
            "# #   # #",
            "# # # # #",
            "#.  @  .#",
            "#########",
        }
    },
    -- 63  boxes=2 goals=2
    {
        name = "Chicane",
        map = {
            "#######",
            "#  @  #",
            "#  $# #",
            "## .  #",
            " # $# #",
            " # .  #",
            " ######",
        }
    },
    -- 64  boxes=3 goals=3
    {
        name = "Trapezoid",
        map = {
            "  #######",
            " ##     #",
            "##  $ $ #",
            "#  $... #",
            "#   @   #",
            "#########",
        }
    },
    -- 65  boxes=4 goals=4
    {
        name = "Windmill",
        map = {
            " #######",
            "## . . ##",
            "#  $ $  #",
            "#   @   #",
            "#  $ $  #",
            "## . . ##",
            " #######",
        }
    },
    -- 66  boxes=2 goals=2
    {
        name = "Flip",
        map = {
            " ######",
            " #    #",
            "##.## #",
            "#   # #",
            "# $@$ #",
            "#  .###",
            "#  #",
            "####",
        }
    },
    -- 67  boxes=2 goals=2
    {
        name = "Overlap",
        map = {
            "#######",
            "# @   #",
            "#$# # #",
            "#.# # #",
            "#   $ #",
            "#   . #",
            "#######",
        }
    },
    -- 68  boxes=4 goals=4
    {
        name = "Double Back",
        map = {
            "########",
            "#  @   #",
            "# $##$ #",
            "#  ##  #",
            "# $##$ #",
            "#  ..  #",
            "#  ..  #",
            "########",
        }
    },
    -- 69  boxes=3 goals=3
    {
        name = "Antechamber",
        map = {
            " ########",
            "##      #",
            "#  $$$  #",
            "#  ...  #",
            "###   ###",
            "  # @ #",
            "  #####",
        }
    },
    -- 70  boxes=5 goals=5
    {
        name = "Conveyor",
        map = {
            "###########",
            "#    @    #",
            "# $$$$$ ##",
            "## ..... #",
            "##########",
        }
    },
    -- 71  boxes=3 goals=3
    {
        name = "Quarters",
        map = {
            "########",
            "#      #",
            "#  $$  #",
            "#  ..  #",
            "##   ###",
            " # $   #",
            " # .@  #",
            " #######",
        }
    },
    -- 72  boxes=2 goals=2
    {
        name = "Snake Path",
        map = {
            "######",
            "#    #",
            "# $. #",
            "#  $ #",
            "## . #",
            " #@  #",
            " #####",
        }
    },
    -- 73  boxes=4 goals=4
    {
        name = "Crossroads",
        map = {
            "  ###  ",
            "###.###",
            "#  $  #",
            "#.$@$.#",
            "#  $  #",
            "###.###",
            "  ###  ",
        }
    },
    -- 74  boxes=4 goals=4
    {
        name = "Chamber",
        map = {
            "   #####",
            "####   #",
            "# $ $  #",
            "# ....@#",
            "# $ $  #",
            "####   #",
            "   #####",
        }
    },
    -- 75  boxes=5 goals=5
    {
        name = "Ricochet",
        map = {
            "##########",
            "#        #",
            "# $.$.$. #",
            "#  #   # #",
            "# .     .#",
            "#  $ @ $ #",
            "##########",
        }
    },
    -- 76  boxes=3 goals=3
    {
        name = "Stack",
        map = {
            "#######",
            "#  .  #",
            "#  $  #",
            "#  .  #",
            "#  $  #",
            "#  .  #",
            "#  $  #",
            "#  @  #",
            "#######",
        }
    },
    -- 77  boxes=2 goals=2
    {
        name = "Bulwark",
        map = {
            "  #####",
            "### @ #",
            "#   $ #",
            "#  $. #",
            "## #. #",
            " #    #",
            " ######",
        }
    },
    -- 78  boxes=6 goals=6
    {
        name = "Tension",
        map = {
            "##########",
            "#  $.$.$ #",
            "#   . .  #",
            "#  $.$.$ #",
            "#    @   #",
            "##########",
        }
    },
    -- 79  boxes=4 goals=4
    {
        name = "Plunge",
        map = {
            "  ######",
            "###    #",
            "#    $ #",
            "## $#  #",
            " # .$. #",
            " ##  $ #",
            "  # .@ #",
            "  # .  #",
            "  ######",
        }
    },
    -- 80  boxes=4 goals=4
    {
        name = "Hub",
        map = {
            "###########",
            "#    @    #",
            "#  $ # $  #",
            "# #     # #",
            "#.#  #  #.#",
            "# #     # #",
            "#  $ # $  #",
            "#   . .   #",
            "###########",
        }
    },
    -- 81  boxes=6 goals=6
    {
        name = "Cluster",
        map = {
            "#########",
            "#       #",
            "#  $$$  #",
            "#  ...  #",
            "#  $$$  #",
            "#  ...  #",
            "#   @   #",
            "#########",
        }
    },
    -- 82  boxes=2 goals=2
    {
        name = "Pincer",
        map = {
            "#########",
            "#.  @  .#",
            "# #   # #",
            "# # # # #",
            "#   $   #",
            "# # $ # #",
            "#   #   #",
            "#########",
        }
    },
    -- 83  boxes=6 goals=6
    {
        name = "Gauntlet",
        map = {
            "############",
            "#    @     #",
            "# $$$$$$ ##",
            "## ...... #",
            "###########",
        }
    },
    -- 84  boxes=4 goals=4
    {
        name = "Outer Rim",
        map = {
            "#########",
            "#   @   #",
            "# $ # $ #",
            "#   #   #",
            "## ### ##",
            "#  . .  #",
            "#  $ $  #",
            "#  . .  #",
            "#########",
        }
    },
    -- 85  boxes=4 goals=4
    {
        name = "Vault",
        map = {
            "########",
            "#  ..  #",
            "#      #",
            "#  $$  #",
            "##    ##",
            " #$$  # ",
            " #..@ # ",
            " ###### ",
        }
    },
    -- 86  boxes=4 goals=4
    {
        name = "Nexus",
        map = {
            "#########",
            "#   @   #",
            "# $ # $ #",
            "# #   # #",
            "# .   . #",
            "#  $ $  #",
            "#  . .  #",
            "#########",
        }
    },
    -- 87  boxes=4 goals=4
    {
        name = "Rampart",
        map = {
            "##########",
            "#   ##   #",
            "# $    $ #",
            "#   ##   #",
            "# $    $ #",
            "##. .. .##",
            " #  @    #",
            " ########",
        }
    },
    -- 88  boxes=8 goals=8
    {
        name = "Long Haul",
        map = {
            "##############",
            "#      @     #",
            "# $$$$$$$$ ##",
            "## ........ #",
            "#############",
        }
    },
    -- 89  boxes=10 goals=10
    {
        name = "Classic II",
        map = {
            "############",
            "#..  #     ###",
            "#..  # $  $  #",
            "#..  #$####  #",
            "#..    @ ##  #",
            "#..  # #  $ ##",
            "###### ##$ $ #",
            "  # $  $ $ $ #",
            "  #    #     #",
            "  ############",
        }
    },
    -- 90  boxes=3 goals=3
    {
        name = "Tributary",
        map = {
            "  #####",
            "###   #",
            "#  $  #",
            "#  $  #",
            "## $# #",
            " # .  #",
            " # .  #",
            " ##.@ #",
            "  #####",
        }
    },
    -- 91  boxes=2 goals=2
    {
        name = "Tandem II",
        map = {
            " ######",
            "##    #",
            "#  $  #",
            "# $@. #",
            "## #. #",
            " #    #",
            " ######",
        }
    },
    -- 92  boxes=2 goals=2
    {
        name = "The Cross",
        map = {
            "   ####",
            "####  #",
            "#   $ #",
            "#  $  #",
            "## #. #",
            " # .  #",
            " # @  #",
            " ######",
        }
    },
    -- 93  boxes=4 goals=4
    {
        name = "Catacomb",
        map = {
            "#########",
            "# # @ # #",
            "# #   # #",
            "#.$.$.$. #",
            "# # $ # #",
            "# #   # #",
            "#########",
        }
    },
    -- 94  boxes=5 goals=5
    {
        name = "Dispatch",
        map = {
            "###########",
            "#         #",
            "# $.$.$.$. #",
            "#          #",
            "#  @  #####",
            "############",
        }
    },
    -- 95  boxes=6 goals=6
    {
        name = "Funnel",
        map = {
            "############",
            "#      @   #",
            "# $$$$$$ ##",
            "## ...... #",
            "###########",
        }
    },
    -- 96  boxes=6 goals=6
    {
        name = "Pinwheel",
        map = {
            "############",
            "#     @    #",
            "# $$$$$$ ##",
            "## ...... #",
            "###########",
        }
    },
    -- 97  boxes=4 goals=4
    {
        name = "Final Push",
        map = {
            "##########",
            "#   ##   #",
            "# $    $ #",
            "#  ####  #",
            "## #..# ##",
            "#  #..#  #",
            "#     $  #",
            "#  @  $  #",
            "##########",
        }
    },
    -- 98  boxes=5 goals=5
    {
        name = "Fortress",
        map = {
            "###########",
            "#    @    #",
            "# #$$$$$# #",
            "# #.....# #",
            "# ##   ## #",
            "#         #",
            "###########",
        }
    },
    -- 99  boxes=4 goals=4
    {
        name = "Labyrinth",
        map = {
            "#############",
            "#     #     #",
            "# $ # # # $ #",
            "# # # # # # #",
            "#   $   $   #",
            "# ### # ### #",
            "#  .  @  .  #",
            "#  .     .  #",
            "#############",
        }
    },
    -- 100  boxes=7 goals=7
    {
        name = "The Summit",
        map = {
            "###########",
            "#    @    #",
            "#  $$$$$  #",
            "# ##   ## #",
            "#.##   ##.#",
            "#  ## ##  #",
            "#  .###.  #",
            "#  . $ .  #",
            "###########",
        }
    },
}

-- ============================================================
-- Constants
-- ============================================================
local CELL         = 40     -- px per grid cell
local PADDING      = 10
local SIDE_W       = 130
local MAX_UNDO     = 50

-- Cell type IDs
local T_EMPTY  = 0
local T_WALL   = 1
local T_GOAL   = 2

-- Colors — dark theme matching other Luna games
local C_BG       = {0.06, 0.06, 0.08}
local C_WALL     = {0.20, 0.20, 0.26}
local C_FLOOR    = {0.12, 0.12, 0.16}
local C_GOAL     = {0.85, 0.75, 0.10}
local C_BOX      = {0.15, 0.38, 0.65}
local C_BOX_DONE = {0.15, 0.60, 0.25}
local C_BORDER   = {0.08, 0.08, 0.10}

-- ============================================================
-- State
-- ============================================================
local gameFrame
local boardFrame
local cellFrames   -- cellFrames[r][c] = {bg, overlay} frames

local levelIndex   = 1
local grid         = {}   -- grid[r][c] = T_EMPTY / T_WALL / T_GOAL
local boxes        = {}   -- boxes[r][c] = true
local playerR, playerC

local moves        = 0
local pushes       = 0
local undoStack    = {}

local numRows, numCols
local bestMoves    = {}   -- bestMoves[levelIndex] = n

-- UI refs
local moveText, pushText, levelText, levelNameText
local winFrame
local playerPortrait  -- the portrait texture on the player cell

-- ============================================================
-- Forward declarations
-- ============================================================
local BuildUI, LoadLevel, RenderAll, TryMove, IsWon

-- ============================================================
-- Level parsing
-- ============================================================
local function ParseLevel(levelDef)
    local rows = {}
    local maxCols = 0
    for _, line in ipairs(levelDef.map) do
        local row = {}
        for i = 1, #line do
            row[#row + 1] = line:sub(i, i)
        end
        rows[#rows + 1] = row
        if #row > maxCols then maxCols = #row end
    end

    local g    = {}
    local b    = {}
    local pr, pc

    for r, row in ipairs(rows) do
        g[r] = {}
        for c = 1, maxCols do
            local ch = row[c] or " "
            if ch == "#" then
                g[r][c] = T_WALL
            elseif ch == "." or ch == "*" or ch == "+" then
                g[r][c] = T_GOAL
            else
                g[r][c] = T_EMPTY
            end

            if ch == "@" or ch == "+" then
                pr, pc = r, c
            end
            if ch == "$" or ch == "*" then
                if not b[r] then b[r] = {} end
                b[r][c] = true
            end
        end
    end

    return g, b, pr or 1, pc or 1, #rows, maxCols
end

-- ============================================================
-- Win check
-- ============================================================
IsWon = function()
    for r = 1, numRows do
        for c = 1, numCols do
            if grid[r][c] == T_GOAL then
                if not (boxes[r] and boxes[r][c]) then
                    return false
                end
            end
        end
    end
    return true
end

-- ============================================================
-- Rendering
-- ============================================================
local function CellColor(r, c)
    local t = grid[r][c]
    local hasBox = boxes[r] and boxes[r][c]
    local isPlayer = (r == playerR and c == playerC)

    if t == T_WALL then
        return C_WALL[1], C_WALL[2], C_WALL[3], 1
    elseif hasBox then
        local onGoal = (t == T_GOAL)
        local col = onGoal and C_BOX_DONE or C_BOX
        return col[1], col[2], col[3], 1
    elseif t == T_GOAL then
        return C_GOAL[1], C_GOAL[2], C_GOAL[3], 0.5
    else
        return C_FLOOR[1], C_FLOOR[2], C_FLOOR[3], 1
    end
end

local function UpdateCell(r, c)
    if not cellFrames or not cellFrames[r] or not cellFrames[r][c] then return end
    local cf = cellFrames[r][c]
    local isPlayer = (r == playerR and c == playerC)
    local t = grid[r][c]
    local hasBox = boxes[r] and boxes[r][c]

    -- Background color
    local br, bg, bb, ba = CellColor(r, c)
    cf.bg:SetColorTexture(br, bg, bb, ba)

    -- Box overlay label
    if cf.boxLabel then
        local onGoal = (t == T_GOAL) and hasBox
        cf.boxLabel:SetShown(hasBox)
        if hasBox then
            cf.boxLabel:SetText(onGoal and "|cFF44FF66[*]|r" or "|cFFCC8822[ ]|r")
        end
    end

    -- Goal dot
    if cf.goalDot then
        cf.goalDot:SetShown(t == T_GOAL and not hasBox and not isPlayer)
    end

    -- Player portrait
    if cf.portrait then
        cf.portrait:SetShown(isPlayer and not hasBox)
    end
end

RenderAll = function()
    if not cellFrames then return end
    for r = 1, numRows do
        for c = 1, numCols do
            UpdateCell(r, c)
        end
    end
end

-- ============================================================
-- Move logic
-- ============================================================
TryMove = function(dr, dc)
    if not playerR then return end

    local nr = playerR + dr
    local nc = playerC + dc

    if nr < 1 or nr > numRows or nc < 1 or nc > numCols then return end
    if grid[nr][nc] == T_WALL then return end

    local pushed = false

    if boxes[nr] and boxes[nr][nc] then
        -- Check where the box would go
        local br = nr + dr
        local bc = nc + dc
        if br < 1 or br > numRows or bc < 1 or bc > numCols then return end
        if grid[br][bc] == T_WALL then return end
        if boxes[br] and boxes[br][bc] then return end

        -- Save undo state before push
        local snapshot = { pr = playerR, pc = playerC, boxR = nr, boxC = nc, br = br, bc = bc, pushed = true }
        if #undoStack >= MAX_UNDO then table.remove(undoStack, 1) end
        undoStack[#undoStack + 1] = snapshot

        -- Move box
        boxes[nr][nc] = nil
        if not boxes[br] then boxes[br] = {} end
        boxes[br][bc] = true
        pushed = true
        pushes = pushes + 1
    else
        -- Simple move — save undo
        local snapshot = { pr = playerR, pc = playerC, pushed = false }
        if #undoStack >= MAX_UNDO then table.remove(undoStack, 1) end
        undoStack[#undoStack + 1] = snapshot
    end

    local prevR, prevC = playerR, playerC
    playerR = nr
    playerC = nc
    moves = moves + 1

    -- Only redraw affected cells
    UpdateCell(prevR, prevC)
    UpdateCell(playerR, playerC)
    if pushed then
        local br = nr + dr
        local bc = nc + dc
        UpdateCell(br, bc)
    end

    UpdateHUD()

    if IsWon() then
        -- Record best
        local prev = bestMoves[levelIndex]
        if not prev or moves < prev then
            bestMoves[levelIndex] = moves
            if UIThingsDB.games and UIThingsDB.games.boxes then
                UIThingsDB.games.boxes.best = UIThingsDB.games.boxes.best or {}
                UIThingsDB.games.boxes.best[levelIndex] = moves
            end
        end
        C_Timer.After(0.3, function()
            if winFrame then winFrame:Show() end
        end)
    end
end

local function UndoMove()
    if #undoStack == 0 then return end
    local snap = table.remove(undoStack)

    if snap.pushed then
        -- Move box back
        boxes[snap.br][snap.bc] = nil
        if not boxes[snap.boxR] then boxes[snap.boxR] = {} end
        boxes[snap.boxR][snap.boxC] = true
        pushes = math.max(0, pushes - 1)
    end

    playerR, playerC = snap.pr, snap.pc
    moves = math.max(0, moves - 1)
    RenderAll()
    UpdateHUD()
    if winFrame then winFrame:Hide() end
end

-- ============================================================
-- HUD
-- ============================================================
function UpdateHUD()
    if moveText  then moveText:SetText("Moves\n" .. moves) end
    if pushText  then pushText:SetText("Pushes\n" .. pushes) end
    if levelText then
        local best = bestMoves[levelIndex]
        local bestStr = best and ("\nBest: " .. best) or ""
        levelText:SetText("Level " .. levelIndex .. " / " .. #LEVELS .. bestStr)
    end
end

-- ============================================================
-- Load level
-- ============================================================
LoadLevel = function(idx)
    levelIndex = idx
    local def = LEVELS[idx]

    grid, boxes, playerR, playerC, numRows, numCols = ParseLevel(def)
    moves  = 0
    pushes = 0
    wipe(undoStack)

    -- Load best from saved vars
    if UIThingsDB.games and UIThingsDB.games.boxes and UIThingsDB.games.boxes.best then
        bestMoves[levelIndex] = UIThingsDB.games.boxes.best[levelIndex]
    end

    if levelNameText then levelNameText:SetText(def.name) end

    -- Rebuild cell grid if board size changed or first load
    BuildCellGrid()
    RenderAll()
    UpdateHUD()
    if winFrame then winFrame:Hide() end
end

-- ============================================================
-- Cell grid builder (called each level load)
-- ============================================================
function BuildCellGrid()
    if not boardFrame then return end

    -- Clear old cells
    if cellFrames then
        for r = 1, #cellFrames do
            for c = 1, #cellFrames[r] do
                cellFrames[r][c].frame:Hide()
            end
        end
    end

    cellFrames = {}

    local bw = numCols * CELL
    local bh = numRows * CELL
    boardFrame:SetSize(bw, bh)

    -- Resize game frame to fit
    -- Min height 340 ensures side panel buttons (anchored top-down) never overflow the frame
    local totalW = bw + PADDING * 3 + SIDE_W
    local totalH = math.max(bh + PADDING * 2 + 30, 340)
    gameFrame:SetSize(totalW, totalH)

    for r = 1, numRows do
        cellFrames[r] = {}
        for c = 1, numCols do
            local f = CreateFrame("Frame", nil, boardFrame)
            f:SetSize(CELL - 1, CELL - 1)
            f:SetPoint("TOPLEFT", boardFrame, "TOPLEFT", (c-1)*CELL, -(r-1)*CELL)

            -- Background texture
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(C_FLOOR[1], C_FLOOR[2], C_FLOOR[3], 1)

            -- Border
            local border = f:CreateTexture(nil, "BORDER")
            border:SetAllPoints()
            border:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4)

            -- Inner shrink for border illusion
            bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
            bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

            -- Goal dot
            local goalDot = f:CreateTexture(nil, "ARTWORK")
            goalDot:SetPoint("CENTER")
            goalDot:SetSize(CELL * 0.3, CELL * 0.3)
            goalDot:SetColorTexture(C_GOAL[1], C_GOAL[2], C_GOAL[3], 0.9)
            goalDot:Hide()

            -- Box label (text overlay, simpler than a separate texture)
            local boxLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            boxLabel:SetPoint("CENTER")
            boxLabel:SetText("[ ]")
            boxLabel:Hide()

            -- Player portrait
            local portrait = f:CreateTexture(nil, "OVERLAY")
            portrait:SetPoint("CENTER")
            portrait:SetSize(CELL - 6, CELL - 6)
            portrait:SetTexture("Interface\\Icons\\INV_Misc_Head_Human_02")
            portrait:Hide()

            -- Try to use the actual player portrait
            if UnitExists("player") then
                SetPortraitTexture(portrait, "player")
            end

            f.bg        = bg
            f.goalDot   = goalDot
            f.boxLabel  = boxLabel
            f.portrait  = portrait
            f.frame     = f

            cellFrames[r][c] = f
        end
    end
end

-- ============================================================
-- UI construction (called once)
-- ============================================================
BuildUI = function()
    gameFrame = CreateFrame("Frame", "LunaUITweaks_BoxesGame", UIParent, "BackdropTemplate")
    gameFrame:SetSize(600, 400)
    gameFrame:SetPoint("CENTER")
    gameFrame:SetFrameStrata("DIALOG")
    gameFrame:SetMovable(true)
    gameFrame:SetClampedToScreen(true)
    gameFrame:RegisterForDrag("LeftButton")
    gameFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    gameFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    gameFrame:Hide()

    -- Background
    local bgTex = gameFrame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(C_BG[1], C_BG[2], C_BG[3], 0.97)

    local borderTex = gameFrame:CreateTexture(nil, "BORDER")
    borderTex:SetAllPoints()
    borderTex:SetColorTexture(0.25, 0.25, 0.30, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, gameFrame)
    titleBar:SetPoint("TOPLEFT",  gameFrame, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() gameFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() gameFrame:StopMovingOrSizing() end)

    local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBarBg:SetAllPoints()
    titleBarBg:SetColorTexture(0.12, 0.12, 0.16, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("|cFFFFD100Boxes|r  |cFF888888drag to move|r")

    local closeBtn = CreateFrame("Button", nil, gameFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", gameFrame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() gameFrame:Hide() end)

    -- Board frame
    boardFrame = CreateFrame("Frame", nil, gameFrame)
    boardFrame:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", PADDING, -(PADDING + 30))

    local boardBg = boardFrame:CreateTexture(nil, "BACKGROUND")
    boardBg:SetAllPoints()
    boardBg:SetColorTexture(0.10, 0.10, 0.13, 1)

    -- ── Side panel ───────────────────────────────────────────
    local sideX    = PADDING  -- relative to right of board; set after board is sized
    local sideTopY = PADDING + 30

    -- We anchor side panel elements to boardFrame RIGHT after build
    local sideAnchor = CreateFrame("Frame", nil, gameFrame)
    sideAnchor:SetPoint("TOPLEFT", boardFrame, "TOPRIGHT", PADDING, 0)
    sideAnchor:SetSize(SIDE_W, 1)

    levelNameText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelNameText:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, -4)
    levelNameText:SetWidth(SIDE_W)
    levelNameText:SetJustifyH("LEFT")
    levelNameText:SetTextColor(1, 0.82, 0.1)
    levelNameText:SetText("")

    levelText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelText:SetPoint("TOPLEFT", levelNameText, "BOTTOMLEFT", 0, -4)
    levelText:SetWidth(SIDE_W)
    levelText:SetJustifyH("LEFT")
    levelText:SetTextColor(0.7, 0.7, 0.7)

    moveText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moveText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -12)
    moveText:SetJustifyH("LEFT")
    moveText:SetText("Moves\n0")

    pushText = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pushText:SetPoint("TOPLEFT", moveText, "BOTTOMLEFT", 0, -8)
    pushText:SetJustifyH("LEFT")
    pushText:SetText("Pushes\n0")

    -- Keybind display
    local BINDS = {
        { label = "Up",    binding = "LUNAUITWEAKS_GAME_ROTATECW"  },
        { label = "Down",  binding = "LUNAUITWEAKS_GAME_ROTATECCW" },
        { label = "Left",  binding = "LUNAUITWEAKS_GAME_LEFT"      },
        { label = "Right", binding = "LUNAUITWEAKS_GAME_RIGHT"     },
        { label = "Undo",  binding = "LUNAUITWEAKS_GAME_PAUSE"     },
    }

    local bindBaseY = -160
    local BIND_ROW_H = 13
    for i, entry in ipairs(BINDS) do
        local lbl = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, bindBaseY - (i-1)*BIND_ROW_H)
        lbl:SetTextColor(0.6, 0.6, 0.6)
        lbl:SetText(entry.label)

        local keyLbl = sideAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        keyLbl:SetPoint("TOPRIGHT", sideAnchor, "TOPRIGHT", 0, bindBaseY - (i-1)*BIND_ROW_H)
        keyLbl:SetJustifyH("RIGHT")
        local key = GetBindingKey(entry.binding)
        if key then
            keyLbl:SetText(key)
            keyLbl:SetTextColor(1, 0.82, 0)
        else
            keyLbl:SetText("--")
            keyLbl:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- ── Buttons — anchored top-down below keybind labels ─────
    local BTN_W = SIDE_W - 4
    local BTN_H = 24
    local BTN_GAP = 6
    -- keybinds end at bindBaseY - 4 * BIND_ROW_H = -160 - 52 = -212 from sideAnchor top
    local BTN_TOP_Y = -160 - 5 * BIND_ROW_H - BTN_GAP

    local restartBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    restartBtn:SetSize(BTN_W, BTN_H)
    restartBtn:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, BTN_TOP_Y)
    restartBtn:SetText("Restart")
    restartBtn:SetScript("OnClick", function() LoadLevel(levelIndex) end)

    -- Prev / Next level buttons (small, side by side)
    local prevBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    prevBtn:SetSize((BTN_W - 2) / 2, BTN_H)
    prevBtn:SetPoint("TOPLEFT", sideAnchor, "TOPLEFT", 0, BTN_TOP_Y - BTN_H - BTN_GAP)
    prevBtn:SetText("< Prev")
    prevBtn:SetScript("OnClick", function()
        if levelIndex > 1 then LoadLevel(levelIndex - 1) end
    end)

    local nextBtn = CreateFrame("Button", nil, gameFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize((BTN_W - 2) / 2, BTN_H)
    nextBtn:SetPoint("TOPRIGHT", sideAnchor, "TOPRIGHT", 0, BTN_TOP_Y - BTN_H - BTN_GAP)
    nextBtn:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        if levelIndex < #LEVELS then LoadLevel(levelIndex + 1) end
    end)

    -- ── Win overlay ──────────────────────────────────────────
    winFrame = CreateFrame("Frame", nil, boardFrame)
    winFrame:SetAllPoints()
    winFrame:SetFrameLevel(boardFrame:GetFrameLevel() + 20)

    local winBg = winFrame:CreateTexture(nil, "ARTWORK")
    winBg:SetAllPoints()
    winBg:SetColorTexture(0, 0, 0, 0.75)

    local winTitle = winFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    winTitle:SetPoint("CENTER", winFrame, "CENTER", 0, 40)
    winTitle:SetText("|cFFFFD100Level Clear!|r")

    winFrame.movesText = winFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    winFrame.movesText:SetPoint("CENTER", winFrame, "CENTER", 0, 8)
    winFrame.movesText:SetJustifyH("CENTER")

    local winNextBtn = CreateFrame("Button", nil, winFrame, "UIPanelButtonTemplate")
    winNextBtn:SetSize(110, 26)
    winNextBtn:SetPoint("CENTER", winFrame, "CENTER", 30, -30)
    winNextBtn:SetText("Next Level")
    winNextBtn:SetScript("OnClick", function()
        if levelIndex < #LEVELS then
            LoadLevel(levelIndex + 1)
        else
            winFrame:Hide()
        end
    end)

    local winRestartBtn = CreateFrame("Button", nil, winFrame, "UIPanelButtonTemplate")
    winRestartBtn:SetSize(80, 26)
    winRestartBtn:SetPoint("CENTER", winFrame, "CENTER", -50, -30)
    winRestartBtn:SetText("Redo")
    winRestartBtn:SetScript("OnClick", function() LoadLevel(levelIndex) end)

    winFrame:Hide()

    -- Update win overlay text when shown
    winFrame:SetScript("OnShow", function()
        local best = bestMoves[levelIndex]
        winFrame.movesText:SetText(
            string.format("Moves: %d   Pushes: %d%s", moves, pushes,
                best and ("\nBest: " .. best) or ""))
    end)
end

-- ============================================================
-- Combat handling
-- ============================================================
addonTable.EventBus.Register("PLAYER_REGEN_DISABLED", function()
    if not (gameFrame and gameFrame:IsShown()) then return end
    if UIThingsDB.games and UIThingsDB.games.closeInCombat then
        gameFrame:Hide()
    end
end)

-- ============================================================
-- Public API
-- ============================================================
function addonTable.Boxes.CloseGame()
    if gameFrame and gameFrame:IsShown() then
        gameFrame:Hide()
    end
end

function addonTable.Boxes.ShowGame()
    if not gameFrame then
        BuildUI()
        -- Load best scores from saved vars
        if UIThingsDB.games and UIThingsDB.games.boxes and UIThingsDB.games.boxes.best then
            for k, v in pairs(UIThingsDB.games.boxes.best) do
                bestMoves[k] = v
            end
        end
        LoadLevel(levelIndex)
    end
    if gameFrame:IsShown() then
        addonTable.Boxes.CloseGame()
    else
        -- Close other games that share keybindings
        if addonTable.Snek     then addonTable.Snek.CloseGame() end
        if addonTable.Game2048 then addonTable.Game2048.CloseGame() end
        gameFrame:Show()
    end
end

-- ============================================================
-- Keybinding chain — wrap existing stubs from Games.lua
-- ============================================================
local function BoxesIsOpen()
    return gameFrame and gameFrame:IsShown()
end

local _origLeft     = LunaUITweaks_Game_Left
local _origRight    = LunaUITweaks_Game_Right
local _origRotateCW = LunaUITweaks_Game_RotateCW
local _origRotateCCW= LunaUITweaks_Game_RotateCCW
local _origPause    = LunaUITweaks_Game_Pause

function LunaUITweaks_Game_Left()
    if BoxesIsOpen() then TryMove(0, -1)
    elseif _origLeft then _origLeft() end
end

function LunaUITweaks_Game_Right()
    if BoxesIsOpen() then TryMove(0, 1)
    elseif _origRight then _origRight() end
end

function LunaUITweaks_Game_RotateCW()
    if BoxesIsOpen() then TryMove(-1, 0)
    elseif _origRotateCW then _origRotateCW() end
end

function LunaUITweaks_Game_RotateCCW()
    if BoxesIsOpen() then TryMove(1, 0)
    elseif _origRotateCCW then _origRotateCCW() end
end

function LunaUITweaks_Game_Pause()
    if BoxesIsOpen() then UndoMove()
    elseif _origPause then _origPause() end
end
