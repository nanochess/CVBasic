' BOOM! NES v1.0.25 
' Compiles with CVBasic v0.90 
' Steve Engelhardt
' 12/29/2025

' -- Global Palettes --
PALETTE 0, $0F 
PALETTE 1, $1A 
PALETTE 2, $01 
PALETTE 3, $00 

' -- Sprite Palettes --
' Palette 0: Bomber & General (Black, White, Orange)
PALETTE 16, $0F 
PALETTE 17, $0F 
PALETTE 18, $30 ' White (Face)
PALETTE 19, $27 

' Palette 1: Bombs (Black, White, Red)
PALETTE 20, $0F 
PALETTE 21, $0F 
PALETTE 22, $00 
PALETTE 23, $30 

' Palette 2: Score (Orange)
PALETTE 24, $0F 
PALETTE 25, $0F 
PALETTE 26, $0F 
PALETTE 27, $27

' Palette 3: Buckets (Black, Blue, Brown)
PALETTE 28, $0F ' Transparent
PALETTE 29, $0F ' 1 = Black (Outline)
PALETTE 30, $12 ' 2 = Blue (Water)
PALETTE 31, $07 ' 3 = Dark Brown (Body)

' -- Variables --

' Bomb Arrays (Up to 8 active bombs)
DIM bomb_x(8)       ' Horizontal position of each active bomb
DIM bomb_y(8)       ' Vertical position of each active bomb
DIM bomb_s(8)       ' Status of bomb slot (0=Inactive, 1=Active)

' Player Bucket (Paddle)
DIM x_bucket        ' Current X position of player buckets
DIM y_bucket        ' Vertical anchor for buckets (usually static)

' Bomber (Bomber)
DIM x_bomber        ' Current X position of the Bomber
DIM y_bomber        ' Current Y position of the Bomber
DIM bomber_dir      ' Movement direction (0=Left, 1=Right)
DIM bomber_timer    ' Timer used for random direction changes
DIM bomber_attr     ' Sprite attribute (used for horizontal flipping)

' Loop & Utility
DIM digit           ' Temporary variable for digit calculations
DIM c               ' Primary loop counter (Universal)
DIM lives           ' Remaining buckets (1 to 3)
DIM r               ' Secondary loop counter / temp math flag
DIM spawn_timer     ' Frames until the next bomb can drop
DIM wait_timer      ' General purpose delay timer

' Drawing & Flicker Control
DIM col1_x          ' Sprite column 1 X offset
DIM col2_x          ' Sprite column 2 X offset
DIM col3_x          ' Sprite column 3 X offset
DIM col4_x          ' Sprite column 4 X offset
DIM b_vis_1         ' Visibility/Y-pos for bucket row 1
DIM b_vis_2         ' Visibility/Y-pos for bucket row 2
DIM b_vis_3         ' Visibility/Y-pos for bucket row 3

' Difficulty & Game Loop
DIM bomb_speed      ' Falling speed (pixels per frame)
DIM max_spawn_delay ' Base delay between bomb drops for current wave
DIM rng_seed        ' Rolling counter used for random numbers
DIM hit_detected    ' Flag (1 if bomb caught, 0 if not)
DIM difficulty      ' Skill level (0=Easy, 1=Std, 2=Hard)
DIM input_delay     ' Prevents rapid-fire menu scrolling
DIM hit_width       ' Collision width based on bucket size
DIM right_limit     ' Screen boundary based on bucket size

' Velocity / Smooth Movement
DIM b_dir           ' Current velocity direction (0=none, 1=L, 2=R)
DIM b_speed         ' Current pixel-speed of momentum
DIM b_subpixel      ' Fractional movement for smooth acceleration

' Wave Logic
DIM wave            ' Current wave number
DIM bombs_remaining ' Bombs left to drop in current wave
DIM active_bombs    ' Current count of bombs on screen
DIM found_slot      ' Used to find available array index for new bomb

' Current Score Digit Variables (for display)
DIM d_tthou         ' Ten-Thousands digit
DIM d_thou          ' Thousands digit
DIM d_hund          ' Hundreds digit
DIM d_tens          ' Tens digit
DIM d_ones          ' Ones digit
DIM temp_val        ' Temp storage for scoring and PPU logic

' High Score Digit Variables
DIM h_tthou         ' High Score: Ten-Thousands
DIM h_thou          ' High Score: Thousands
DIM h_hund          ' High Score: Hundreds
DIM h_tens          ' High Score: Tens
DIM h_ones          ' High Score: Ones

' Splash Animation Arrays
DIM splash_x(3)     ' Horizontal offset for catch splash
DIM splash_y(3)     ' Vertical offset for catch splash
DIM splash_t(3)     ' Frames remaining for splash animation

' Menu & Rotation
DIM control_type    ' 0=Digital, 1=Velocity
DIM menu_sel        ' Current menu cursor selection
DIM s_row1          ' Sprite index for bucket row 1 (Priority rotation)
DIM s_row2          ' Sprite index for bucket row 2 (Priority rotation)
DIM s_row3          ' Sprite index for bucket row 3 (Priority rotation)
DIM s_ex1           ' Extra sprite for Easy mode bucket expansion
DIM s_ex2           ' Extra sprite for Easy mode bucket expansion
DIM s_ex3           ' Extra sprite for Easy mode bucket expansion
DIM last_wave       ' Records wave reached before Game Over

' Music Engine
DIM music_step      ' Current step in the sequence (0-3 or 0-15)
DIM music_timer     ' Frames remaining until next music step
DIM music_pattern   ' Current pattern state (0=Intro, 1=Main, 2=Bridge)
DIM melody_index    ' Note table index for Square 1
DIM harmony_index   ' Note table index for Square 2
DIM bass_index      ' Note table index for Triangle
DIM drum_index      ' Sound type for Noise channel (1=Snare, 2=Kick)
DIM duration        ' Frame length of the current note
DIM music_active    ' Music toggle (1=Play, 0=Silent)
DIM sfx_timer       ' Frames remaining for active Sound Effect


' =========================================================================
'  BOOT
' =========================================================================
boot:
    rng_seed = 0       ' Initialize random seed (will increment during title loop)
    difficulty = 1     ' Default to "Standard" difficulty for a balanced first game
    control_type = 0   ' Default to "Digital" controls as it's most familiar to players
    menu_sel = 0       ' Start the menu cursor on the first row (Skill selection)

    ' -- Initialize Music State --
    music_active = 1   ' Enable the music engine so the title theme plays immediately
    music_pattern = 0  ' Start with the Intro sequence rather than the main loop
    music_timer = 0    ' Set to 0 so the engine triggers the first note instantly
    music_step = 0     ' Start at the very first note (Step 0) of the Intro

' =========================================================================
'  TITLE SCREEN
' =========================================================================
title_screen:
    SCREEN DISABLE
    CLS 

    ' -- Title Palettes --
    ' Palette 0: Borders & Buildings
    PALETTE 0, $0F  ' Slot 0 (Transparent/Global Back - Black)
    PALETTE 1, $16  ' Slot 1 (Outer Border "*" - Dark Blue)
    PALETTE 2, $01  ' Slot 2 (Medium Blue/Navy)
    PALETTE 3, $10  ' Slot 3 (Light Grey)

    ' Palette 1: BOOM! Logo
    PALETTE 4, $0F  ' Slot 0 (Black)
    PALETTE 5, $16  ' Slot 1 (Logo - Dark Blue) 
    PALETTE 6, $01  ' Slot 2 (Navy)
    PALETTE 7, $10  ' Slot 3 (Light Grey)

    ' Palette 2: Box Borders
    PALETTE 8, $0F  ' Slot 0 (Black)
    PALETTE 9, $0F  ' Slot 1 (Inner Borders "\201" - Black)
    PALETTE 10, $01 ' Slot 2 (Navy)
    PALETTE 11, $10 ' Slot 3 (Light Grey)

    ' Palette 3: UI Text
    PALETTE 12, $0F ' Slot 0 (Black)
    PALETTE 13, $10 ' Slot 1 (Text - Light Grey)
    PALETTE 14, $01 ' Slot 2 (Navy)
    PALETTE 15, $10 ' Slot 3 (Light Grey)

    ' Sprite Palette 0: Title Screen Bomber (Bomber)
    PALETTE 16, $0F ' Slot 0 (Transparent)
    PALETTE 17, $0F ' Slot 1 (Black Outline)
    PALETTE 18, $30 ' Slot 2 (Face/Eyes - White)
    PALETTE 19, $27 ' Slot 3 (Clothes/Hat - Orange)

    ' -- DRAWING PHASE 1: Top Borders --
    PRINT AT 0, "********************************"
    PRINT AT 32, "********************************"
    PRINT AT 64, "*((((((((((((((((((((((((((((((*"
    PRINT AT 96, "*((((((((((((((((((((((((((((((*"
    PRINT AT 128, "*((((((((((((((((((((((((((((((*"
    PRINT AT 160, "*((((((((((((((((((((((((((((((*"

    WAIT 

    ' -- DRAWING PHASE 2: Logo Area --
    PRINT AT 192, "*((((((((((((((((((((((((((((((*"
    PRINT AT 224, "*((((((((((((((((((((((((((((((*"
    PRINT AT 256, "*((((((((((((((((((((((((((((((*"
    PRINT AT 288, "*((((((((((((((((((((((((((((((*"
    PRINT AT 320, "*((((((((((((((((((((((((((((((*"
    PRINT AT 352, "*((((((((((((((((((((((((((((((*"
    PRINT AT 384, "*((((((((((((((((((((((((((((((*"

    WAIT

    ' -- DRAWING PHASE 3: Score Box --
    PRINT AT 416, "*(((((\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201(((((*"
    PRINT AT 448, "*(((((\201                  \201(((((*" 
    PRINT AT 480, "*(((((\201                  \201(((((*" 
    PRINT AT 512, "*(((((\201                  \201(((((*" 
    PRINT AT 544, "*(((((\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201(((((*" 

    PRINT AT 576, "*((((((((((((((((((((((((((((((*"

    WAIT

    ' -- DRAWING PHASE 4: Difficulty Box --
    PRINT AT 608, "*(((((\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201(((((*"
    PRINT AT 640, "*(((((\201                  \201(((((*"
    PRINT AT 672, "*(((((\201                  \201(((((*"
    PRINT AT 704, "*(((((\201                  \201(((((*"
    PRINT AT 736, "*(((((\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201\201(((((*"

    WAIT

    ' -- DRAWING PHASE 5: Bottom Closure --
    PRINT AT 768, "*((((((((((((((((((((((((((((((*"
    PRINT AT 800, "********************************"

    WAIT

    ' Row 27 (864 + 4): Copyright shifted up one row
    PRINT AT 868, "\127 2026 STEVE ENGELHARDT"

    ' Sprites for Bomber
    SPRITE 0, 16, 110, 128, 0
    SPRITE 1, 16, 110 + 8, 130, 0
    SPRITE 2, 16 + 16, 110, 132, 0
    SPRITE 3, 16 + 16, 110 + 8, 134, 0

    ' Hide all unused sprites (4-63) by moving them off-screen to Y=240
    FOR c = 4 TO 63: SPRITE c, 240, 0, 0, 0: NEXT c

    ' Title Logo (BOOM!)
    PRINT AT 197, "\200\200\200" 
    PRINT AT 229, "\200((\200"
    PRINT AT 261, "\200\200\200" 
    PRINT AT 293, "\200((\200"
    PRINT AT 325, "\200\200\200"
    PRINT AT 202, "(\200\200(" 
    PRINT AT 234, "\200((\200"
    PRINT AT 266, "\200((\200" 
    PRINT AT 298, "\200((\200"
    PRINT AT 330, "(\200\200("
    PRINT AT 207, "(\200\200(" 
    PRINT AT 239, "\200((\200"
    PRINT AT 271, "\200((\200" 
    PRINT AT 303, "\200((\200"
    PRINT AT 335, "(\200\200("
    PRINT AT 212, "\200(((\200" 
    PRINT AT 244, "\200\200(\200\200"
    PRINT AT 276, "\200(\200(\200" 
    PRINT AT 308, "\200(((\200"
    PRINT AT 340, "\200(((\200"
    PRINT AT 218, "\200" 
    PRINT AT 250, "\200"
    PRINT AT 282, "\200" 
    PRINT AT 346, "\200"

    ' -- HIGH SCORE (Row 14, Col 7) --
    PRINT AT 455, "HIGH SCORE:  ", d_tthou, d_thou, d_hund, d_tens, d_ones

    ' -- LAST SCORE (Row 15, Col 7) --
    PRINT AT 487, "LAST SCORE:  ", d_tthou, d_thou, d_hund, d_tens, d_ones

    ' -- LAST WAVE (Row 16, Col 7) --
    temp_val = last_wave
    ' Calculate wave digits manually
    r = temp_val / 10
    c = temp_val % 10
    PRINT AT 519, "LAST WAVE:   ", 0, 0, 0, r, c

   ' Labels
    PRINT AT 647, "SKILL:"
    PRINT AT 679, "CONTROLS:"
    PRINT AT 711, "PRESS A TO START"

    SCREEN ENABLE       ' Turn on the PPU to begin displaying the title screen
    input_delay = 0     ' Reset controller delay so menu navigation is instant

    ' -- Title Screen Music Initialization --
    music_step = 0      ' Start sequence at the first note
    music_timer = 0     ' Reset timer to trigger the first note immediately
    music_pattern = 0   ' Start with Intro (Pattern 0) 
    music_active = 1    ' Enable the music engine for the title loop

    ' -- Setup Title Bomber (Bomber) --
    x_bomber = 110      ' Center the Bomber horizontally at start
    y_bomber = 16       ' Position Bomber at the top of the screen
    bomber_dir = 1      ' Set initial movement to the Right
    bomber_timer = 0    ' Reset movement timer for random direction changes

    ' -- Setup Title Bomb (Sprite 11) --
    ' This manages the bomb that falls behind the title screen text
    found_slot = 0      ' State: 0 = Ready to drop, 1 = Currently falling
    temp_val = 0        ' Stores current Y position of the title bomb
    r = 0               ' Stores current X position of the title bomb

title_loop:
    WAIT                ' Synchronize with the NES Vertical Blank (60 frames per second)
    
    ' Call the music sequencer every frame if it is currently enabled
    IF music_active = 1 THEN GOSUB title_music_update

    ' Increment the random number generator seed while the user is on the title screen
    rng_seed = rng_seed + 1

    ' --- RANDOM BOMBER MOVEMENT (Logo Range: 40 to 199) ---
    bomber_timer = bomber_timer + 1   ' Increment the decision timer
    
    ' Check every 11 frames to see if the Bomber wants to change direction
    IF bomber_timer > 10 THEN
        bomber_timer = 0               ' Reset the decision timer
        c = RANDOM(127)                ' Generate a random value between 0 and 127
        IF c > 100 THEN bomber_dir = 1 ' Small chance to force movement Right
        IF c < 27 THEN bomber_dir = 0  ' Small chance to force movement Left
    END IF

    ' Apply movement based on current direction
    IF bomber_dir = 1 THEN
        x_bomber = x_bomber + 2        ' Move Right at a constant title-speed
        
        ' Right Limit: 199 (Strictly above the main logo text)
        IF x_bomber > 199 THEN 
            x_bomber = 199             ' Snap back to the boundary edge
            bomber_dir = 0             ' Force direction change to Left
            bomber_timer = 0           ' Reset timer to prevent instant jitter
        END IF
    ELSE
        x_bomber = x_bomber - 2        ' Move Left at a constant title-speed
        
        ' Left Limit: Start of the "B" (40)
        IF x_bomber < 40 THEN 
            x_bomber = 40              ' Snap back to the boundary edge
            bomber_dir = 1             ' Force direction change to Right
            bomber_timer = 0           ' Reset timer to prevent instant jitter
        END IF
    END IF

    ' --- TITLE BOMB LOGIC (Decorative Animation) ---
    ' Check if the title bomb is currently "reloading" or active
    IF found_slot = 0 THEN
        ' Bomb is ready: Roll for a random drop chance (~11% chance per frame)
        c = RANDOM(255)
        IF c > 225 THEN
            found_slot = 1            ' Set state to "Falling"
            temp_val = y_bomber + 16  ' Set start Y relative to Bomber's height
            r = x_bomber + 4          ' Set start X to center under the Bomber
        END IF
    ELSE
        ' Bomb is active: Move it down 2 pixels per frame
        temp_val = temp_val + 2
        
        ' Update hardware Sprite 11 (Pattern 138, Palette 1)
        SPRITE 11, temp_val, r, 138, 1
        
        ' Check if bomb reached the "Floor" of the title logo area
        IF temp_val >= 88 THEN
            found_slot = 0            ' Reset state to "Ready"
            temp_val = 0              ' Reset Y position variable
            ' Move Sprite 11 off-screen to Y=240 to hide it until next drop
            SPRITE 11, 240, 0, 0, 0 
        END IF
    END IF

    ' --- DRAW THE BOMBER (Sprites 0-3) ---
    ' This handles the multi-sprite Bomber and flips the tiles when turning
    IF bomber_dir = 1 THEN 
        ' Moving RIGHT: Use standard tile layout and attributes
        SPRITE 0, y_bomber, x_bomber, 128, 0           ' Head Left
        SPRITE 1, y_bomber, x_bomber + 8, 130, 0       ' Head Right
        SPRITE 2, y_bomber + 16, x_bomber, 132, 0      ' Body Left
        SPRITE 3, y_bomber + 16, x_bomber + 8, 134, 0  ' Body Right
    ELSE
        ' Moving LEFT: Swap tile positions and apply Horizontal Flip (Attribute 64)
        SPRITE 0, y_bomber, x_bomber, 130, 64          ' Right tile moves to Left pos, flipped
        SPRITE 1, y_bomber, x_bomber + 8, 128, 64      ' Left tile moves to Right pos, flipped
        SPRITE 2, y_bomber + 16, x_bomber, 134, 64     ' Right body moves to Left, flipped
        SPRITE 3, y_bomber + 16, x_bomber + 8, 132, 64 ' Left body moves to Right, flipped
    END IF

    ' --- MENU LOGIC (Selection & Input Debouncing) ---
    ' Count down the input delay to prevent ultra-fast scrolling
    IF input_delay > 0 THEN
        input_delay = input_delay - 1
    END IF

    ' Process new inputs only when the delay timer has reached zero
    IF input_delay = 0 THEN
        ' NAVIGATE ROWS (Up/Down)
        ' Switch between Skill (0) and Control (1) rows
        IF cont1.up AND menu_sel > 0 THEN
            menu_sel = 0
            input_delay = 12          ' 12-frame pause before next movement
        END IF
        IF cont1.down AND menu_sel < 1 THEN
            menu_sel = 1
            input_delay = 12          ' 12-frame pause before next movement
        END IF

        ' CHANGE VALUES (Left/Right)
        ' Logic depends on which row the cursor is currently on
        IF menu_sel = 0 THEN
            ' Modify Difficulty Level (0=Easy, 1=Std, 2=Hard)
            IF cont1.left AND difficulty > 0 THEN 
                difficulty = difficulty - 1
                input_delay = 10      ' Slightly faster repeat for value changes
            END IF
            IF cont1.right AND difficulty < 2 THEN 
                difficulty = difficulty + 1
                input_delay = 10      ' Slightly faster repeat for value changes
            END IF
        ELSE
            ' Toggle Control Type (0=Standard, 1=Velocity)
            ' This uses binary flipping (1 - current_value)
            IF cont1.left OR cont1.right THEN
                control_type = 1 - control_type
                input_delay = 12      ' Standard pause for toggle
            END IF
        END IF
    END IF

    ' --- REDRAW UI (Text Updates) ---
    ' Update the difficulty box text based on current selection
    IF difficulty = 0 THEN
        PRINT AT 657, "< EASY >"
    ELSEIF difficulty = 1 THEN
        PRINT AT 657, "< STD  >"
    ELSE
        PRINT AT 657, "< HARD >"
    END IF

    ' Update the control mode box text (Standard vs. Velocity)
    IF control_type = 0 THEN
        PRINT AT 689, "< STD  >"
    ELSE
        PRINT AT 689, "< VEL  >"
    END IF

    ' --- DRAW CURSOR (Sprite 10) ---
    ' Position the circular cursor sprite next to the active menu row
    IF menu_sel = 0 THEN
        ' Row 0: Skill/Difficulty (Y=159, X=48, Tile 146, Palette 3)
        SPRITE 10, 159, 48, 146, 3
    ELSE
        ' Row 1: Controls (Y=167, X=48, Tile 146, Palette 3)
        SPRITE 10, 167, 48, 146, 3
    END IF

    ' --- START GAME TRIGGER ---
    ' Check if the Start/A button is pressed to begin the game
    IF cont1.button THEN 
        ' Use the current title-screen timer to finalize the random seed
        c = RANDOM(rng_seed)
        
        ' Clean up UI elements before transitioning
        SPRITE 10, 240, 0, 0, 0    ' Hide the menu cursor off-screen
        music_active = 0           ' Stop the title music sequence
        GOSUB audio_silence_all    ' Immediately kill all active sound registers
        
        GOTO restart               ' Jump to the main game setup
    END IF
    
    GOTO title_loop                ' Repeat the title loop until a button is pressed

' =========================================================================
'  SUBROUTINE: TITLE MUSIC UPDATE
' =========================================================================
title_music_update:

    ' Note-Off / Staccato Logic
    ' Briefly silences channels before a new note to prevent a "slurring" sound
    IF music_timer = 2 THEN
        POKE $4000, $30     ' Mute Square 1 (Melody)
        POKE $4004, $30     ' Mute Square 2 (Harmony)
        POKE $4008, $80     ' Mute Triangle (Bass)
        ' Noise is skipped here to allow drum decay to finish naturally
    END IF

    ' Countdown Timer
    ' Stays on the current note until the duration reaches zero
    IF music_timer > 0 THEN
        music_timer = music_timer - 1
        RETURN              ' Exit sub; note is still playing
    END IF

    ' FETCH DATA & ADVANCE PATTERNS
    ' Determines which musical section we are in and pulls data from arrays
    IF music_pattern = 0 THEN
        ' --- INTRO (4 Steps) ---
        melody_index = title_intro_melody(music_step)
        harmony_index = title_intro_harmony(music_step)
        bass_index = title_intro_bass(music_step)
        drum_index = title_intro_drums(music_step)
        duration = title_intro_duration(music_step)
        
        music_step = music_step + 1
        IF music_step > 3 THEN
            music_step = 0
            music_pattern = 1 ' Advance to Main Loop (Pattern A)
        END IF

    ELSEIF music_pattern = 1 THEN
        ' --- PATTERN A: Main Theme (16 Steps) ---
        melody_index = title_melody(music_step)
        harmony_index = title_harmony(music_step)
        bass_index = title_bass(music_step)
        drum_index = title_drums(music_step)
        duration = title_duration(music_step)
        
        music_step = music_step + 1
        IF music_step > 15 THEN
            music_step = 0
            music_pattern = 2 ' Advance to Bridge (Pattern B)
        END IF

    ELSE
        ' --- PATTERN B: Bridge / Variation (16 Steps) ---
        melody_index = title_melody_b(music_step)
        harmony_index = title_harmony_b(music_step)
        bass_index = title_bass_b(music_step)
        drum_index = title_drums_b(music_step)
        duration = title_duration_b(music_step)
        
        music_step = music_step + 1
        IF music_step > 15 THEN
            music_step = 0
            music_pattern = 1 ' Loop back to Main Theme
        END IF
    END IF

    ' WRITE TO HARDWARE (POKE TO APU REGISTERS)

    ' Square 1 (Melody)
    ' $BF = Duty 10, Length Ctr Disabled, Constant Vol, Vol 15
    IF melody_index = 255 THEN
        POKE $4000, $30     ' Silence channel if data is a REST
    ELSE
        POKE $4000, $BF     ' Set volume and duty cycle
        POKE $4002, note_table_low(melody_index)  ' Fine tune frequency
        POKE $4003, note_table_high(melody_index) ' Course tune frequency & trigger
    END IF

    ' Square 2 (Harmony)
    ' $7A = Duty 01, Length Ctr Disabled, Constant Vol, Vol 10
    IF harmony_index = 255 THEN
        POKE $4004, $30
    ELSE
        POKE $4004, $7A     ' Set volume and different duty for texture
        POKE $4006, note_table_low(harmony_index)
        POKE $4007, note_table_high(harmony_index)
    END IF

    ' Triangle (Bass)
    ' $FF = Linear Counter control enabled
    IF bass_index = 255 THEN
        POKE $4008, $80
    ELSE
        POKE $4008, $FF     ' Turn Triangle ON
        POKE $400A, note_table_low(bass_index)
        POKE $400B, note_table_high(bass_index)
    END IF

    ' Noise (Drums)
    ' Uses Hardware Envelopes ($1x) for percussion decay
    IF drum_index = 1 THEN
        ' Snare Drum: Mid-pitch hiss with decay
        POKE $400C, $18
        POKE $400E, $01
    ELSEIF drum_index = 2 THEN
        ' Kick Drum: Low-frequency thud with decay
        POKE $400C, $1A
        POKE $400E, $0F
    ELSE
        ' Silence Noise Channel
        POKE $400C, $30
    END IF

    ' Start Note Timer
    ' Set duration for the current note before next update cycle
    music_timer = duration

    RETURN

' =========================================================================
'  GAME SETUP
' =========================================================================
restart:

    POKE $4015, $0F   ' enable all APU channels (including noise)

    ' -- GAME PALETTES (Reset for Gameplay) --
    ' Background Palettes (Used by Cityscape and Sky)
    PALETTE 0, $0F  ' Slot 0 (Black - Global Background)
    PALETTE 1, $1A  ' Slot 1 (Green - Floor/Grass)
    PALETTE 2, $01  ' Slot 2 (Medium Blue - Sky/Buildings)
    PALETTE 3, $00  ' Slot 3 (Dark Grey - Buildings)

    ' Sprite Palette 0 (Bomber / Bomber)
    PALETTE 16, $0F ' Slot 0 (Transparent)
    PALETTE 17, $0F ' Slot 1 (Black - Outline)
    PALETTE 18, $30 ' Slot 2 (White - Face/Eyes)
    PALETTE 19, $27 ' Slot 3 (Orange - Hat/Clothes)

    ' Sprite Palette 1 (Bombs)
    PALETTE 20, $0F ' Slot 0 (Transparent)
    PALETTE 21, $0F ' Slot 1 (Black - Fuse/Wick)
    PALETTE 22, $00 ' Slot 2 (Grey - Highlight)
    PALETTE 23, $30 ' Slot 3 (White - Spark)

    ' Sprite Palette 2 (Score Digits)
    PALETTE 24, $0F ' Slot 0 (Transparent)
    PALETTE 25, $0F ' Slot 1 (Black - Drop Shadow)
    PALETTE 26, $0F ' Slot 2 (Black - Unused)
    PALETTE 27, $27 ' Slot 3 (Orange - Digit Color)

    ' Sprite Palette 3 (Buckets & Splash)
    PALETTE 28, $0F ' Slot 0 (Transparent)
    PALETTE 29, $0F ' Slot 1 (Black - Outline)
    PALETTE 30, $12 ' Slot 2 (Blue - Water/Splash)
    PALETTE 31, $07 ' Slot 3 (Dark Brown - Bucket Body)

   ' -- Reset Gameplay Variables --
    score = 0           ' Clear current session score
    d_tthou = 0         ' Reset Ten-Thousands digit display
    d_thou = 0          ' Reset Thousands digit display
    d_hund = 0          ' Reset Hundreds digit display
    d_tens = 0          ' Reset Tens digit display
    d_ones = 0          ' Reset Ones digit display
    lives = 3           ' Start player with a full stack of 3 buckets
    wave = 1            ' Begin the challenge at Wave 1

    ' -- Position Actors --
    x_bucket = 110      ' Start player buckets in the center of the screen
    x_bomber = 110      ' Start the Bomber in the center of the sky
    y_bomber = 26       ' Position the Bomber just below the cityscape skyline
    bomber_dir = 1      ' Set initial Bomber movement to the Right

    ' -- Global Sprite Reset --
    ' Clear all 64 sprites by moving them to Y=255 (Off-screen)
    FOR c = 0 TO 63
        SPRITE c, 255, 0, 0, 0
    NEXT c

    ' -- Difficulty Scaling Update --
    ' Adjust collision math and movement boundaries based on Title Screen selection
    IF difficulty = 0 THEN
        ' EASY: Wide catch area (4 sprites / 32 pixels)
        hit_width = 32 
        right_limit = 216   ' Clamp X earlier to account for wider sprites
    ELSEIF difficulty = 1 THEN
        ' STD: Medium catch area (3 sprites / 24 pixels)
        hit_width = 24 
        right_limit = 224   ' Standard screen clamping
    ELSE
        ' HARD: Narrow catch area (2 sprites / 16 pixels)
        hit_width = 16 
        right_limit = 232   ' Allow further movement to the right
    END IF

    ' -- Reset Splash Animation State --
    ' Clear all active water splash timers and offsets across all 3 bucket rows
    FOR r = 0 TO 2
        splash_t(r) = 0        ' Reset frame timer (kills active splashes)
        splash_x(r) = 0        ' Reset horizontal offset
        splash_y(r) = 0        ' Reset vertical offset
    NEXT r

    ' -- Prepare Display for Game World --
    SCREEN DISABLE             ' Turn off PPU to allow fast background tile writing
    CLS                        ' Clear the current Name Table (background)

    ' Clean OAM (Sprite Memory) by hiding all 64 sprites off-screen
    FOR c = 0 TO 63
        SPRITE c, 240, 0, 0, 0
    NEXT c

    ' --- DRAW STATIC CITYSCAPE ---
    ' Draw the sky/clouds (Pattern 42 '*') across the top 2 rows
    FOR r = 0 TO 1
        PRINT AT r * 32, "***********************(((******"
    NEXT r

    ' Draw the building tops and skyline details (Rows 2-6)
    PRINT AT 2 * 32, "****(((((*(((*((((*****( (*((((("
    PRINT AT 3 * 32, "****( ( (*( (*( ((*****(((*( ( ("
    PRINT AT 4 * 32, "(((*(((((*(((*((((*(((*(((*((((("
    PRINT AT 5 * 32, "( (*( ( (*( (*((((*(((*(((*( ((("
    PRINT AT 6 * 32, "(((*(((((*(((*((((*(((*(((*((((("

    ' Draw the main city wall/floor (Pattern 41 ')') from Row 7 down to 27
    FOR r = 7 TO 27
        PRINT AT r * 32, "))))))))))))))))))))))))))))))))"
    NEXT r

    SCREEN ENABLE              ' Turn display back on now that background is ready

    ' -- Final Game State Initialization --
    ' Ensure all 8 bomb slots are marked as inactive (0) before the wave starts
    FOR c = 0 TO 7
        bomb_s(c) = 0
    NEXT c

    GOSUB new_game_pause       ' Show "Ready?" prompt and wait for player input
    GOTO start_wave            ' Jump to the wave-specific logic and bomb spawning

' =========================================================================
'  WAVE SETUP (Difficulty & Scaling Logic)
' =========================================================================
start_wave:
    spawn_timer = 30           ' Initial 0.5-second pause before the first bomb drops

    ' -- BOMB QUANTITY --
    ' Gradually increase total bombs per wave (e.g., Wave 1 = 17, Wave 10 = 35)
    bombs_remaining = 15 + (wave * 2)

    ' -- VERTICAL FALL SPEED --
    bomb_speed = 2                         ' Base speed for Standard/Easy early waves
    IF difficulty = 2 THEN bomb_speed = 3  ' Hard mode starts at a higher base speed
    IF wave > 2 THEN bomb_speed = 3        ' Increase speed at Wave 3
    IF wave > 5 THEN bomb_speed = 4        ' Increase speed at Wave 6
    IF wave > 8 THEN bomb_speed = 5        ' Increase speed at Wave 9
    
    ' Fairness Speed Cap: Ensure bombs never exceed 5 pixels per frame
    IF bomb_speed > 5 THEN bomb_speed = 5

    ' -- SPAWN DENSITY (The "Rhythm") --
    ' Formula creates a tighter drop interval as waves progress
    max_spawn_delay = 20 - (wave * 2)

    ' Adjust spawn rhythm based on chosen skill level
    IF difficulty = 0 THEN max_spawn_delay = max_spawn_delay + 4  ' Slower drops for Easy
    IF difficulty = 2 THEN max_spawn_delay = max_spawn_delay - 4  ' Faster drops for Hard

    ' fairness Floor: Never drop faster than once every 4 frames (the limit of human reaction)
    IF max_spawn_delay < 4 THEN max_spawn_delay = 4

    WAIT                       ' Final frame sync before jumping into the game loop

' =========================================================================
'  MAIN GAME LOOP
' =========================================================================
game_loop:

 ' --- MOVEMENT SELECTION (Player Input & Physics) ---

    IF control_type = 0 THEN
        ' -- TIGHT CONTROLS (Classic Digital Style) --
        ' Instant 4-pixel movement with boundary checking
        IF cont1.left AND x_bucket > 8 THEN
            x_bucket = x_bucket - 4
        END IF
        IF cont1.right AND x_bucket < right_limit THEN
            x_bucket = x_bucket + 4
        END IF
    ELSE
        ' -- SMOOTH CONTROLS (Momentum Physics + Magnet Assist) --
        
        ' Acceleration Logic
        IF cont1.left THEN
            b_dir = 1                 ' Set intent to Left
            b_subpixel = b_subpixel + 80
            ' If subpixel overflows (8-bit roll), increment actual speed
            IF b_subpixel < 80 THEN
                IF b_speed < 4 THEN b_speed = b_speed + 1
            END IF
        ELSEIF cont1.right THEN
            b_dir = 2                 ' Set intent to Right
            b_subpixel = b_subpixel + 80
            IF b_subpixel < 80 THEN
                IF b_speed < 4 THEN b_speed = b_speed + 1
            END IF
        ELSE
            ' 2. Friction/Deceleration (Active when no buttons are pressed)
            b_subpixel = b_subpixel + 40
            IF b_subpixel < 40 THEN
                IF b_speed > 0 THEN
                    b_speed = b_speed - 1
                ELSE
                    b_dir = 0         ' Full stop
                END IF
            END IF
        END IF

        ' Apply Velocity to Screen Position
        IF b_dir = 1 THEN x_bucket = x_bucket - b_speed
        IF b_dir = 2 THEN x_bucket = x_bucket + b_speed

        ' Magnet Assist (Corrects for near-misses in Smooth mode)
        ' Loops through all active bombs to see if any are close enough to "pull" the bucket
        FOR c = 0 TO 7
            IF bomb_s(c) = 1 THEN
                ' Manual Absolute Difference calculation (8-bit safe)
                temp_val = bomb_x(c) - x_bucket
                IF temp_val > 127 THEN temp_val = 256 - temp_val
                
                ' If bucket is within 12 pixels of a falling bomb, apply a 1-pixel nudge
                IF temp_val < 12 THEN
                    IF b_dir = 2 AND bomb_x(c) > x_bucket THEN x_bucket = x_bucket + 1
                    IF b_dir = 1 AND bomb_x(c) < x_bucket THEN x_bucket = x_bucket - 1
                END IF
            END IF
        NEXT c
    END IF

    ' -- Global Boundary Clamping --
    ' Prevents the bucket from sliding off the left or right edges of the city
    IF x_bucket < 8 THEN
        x_bucket = 8          ' Snap to left boundary
        b_speed = 0           ' Kill momentum in Velocity mode
    END IF
    IF x_bucket > right_limit THEN
        x_bucket = right_limit ' Snap to right boundary (calculated by difficulty)
        b_speed = 0            ' Kill momentum in Velocity mode
    END IF

    ' -- Bomber (Bomber) AI & Movement --
    ' Decision Logic: Every 11 frames, roll for a possible direction change
    bomber_timer = bomber_timer + 1
    IF bomber_timer > 10 THEN
        bomber_timer = 0
        c = RANDOM(127)
        IF c > 100 THEN bomber_dir = 1        ' Shift intent to Right
        IF c < 27 THEN bomber_dir = 0         ' Shift intent to Left
    END IF

    ' Physical Movement & Screen Wrapping
    IF bomber_dir = 1 THEN
        x_bomber = x_bomber + 2               ' Standard horizontal speed
        IF x_bomber > 220 THEN bomber_dir = 0 ' Turn around at right edge
    ELSE
        x_bomber = x_bomber - 2
        IF x_bomber < 16 THEN bomber_dir = 1  ' Turn around at left edge
    END IF

    ' -- Bomb Spawning Logic --
    active_bombs = 0                          ' Reset counter for the frame's update
    
    ' Only decrement spawn timer if there are bombs left in the wave
    IF spawn_timer > 0 THEN spawn_timer = spawn_timer - 1
    
    ' Trigger a new drop when timer hits zero and wave is not empty
    IF spawn_timer = 0 AND bombs_remaining > 0 THEN
        ' Find an empty slot in the bomb array (Indices 0-7)
        FOR c = 0 TO 7
            IF bomb_s(c) = 0 THEN
                bomb_x(c) = x_bomber + 4      ' Spawn at Bomber's current X center
                bomb_y(c) = y_bomber + 24     ' Spawn just below the Bomber's sprites
                bomb_s(c) = 1                 ' Activate the bomb
                spawn_timer = max_spawn_delay ' Reset rhythm timer
                bombs_remaining = bombs_remaining - 1 ' Deduct from wave pool
                c = 7                         ' Exit the search early (one bomb per frame)
            END IF
        NEXT c
    END IF

    FOR c = 0 TO 7
        IF bomb_s(c) = 1 THEN
            active_bombs = active_bombs + 1
            bomb_y(c) = bomb_y(c) + bomb_speed
            hit_detected = 0

            ' Catch zones 
            IF bomb_x(c) > x_bucket - 4 AND bomb_x(c) < x_bucket + hit_width THEN
                ' Bottom bucket row: centered at 212, 8px tall
                IF bomb_y(c) >= 212 AND bomb_y(c) < 220 THEN hit_detected = 1

                ' Middle bucket row (only if 2+ lives): centered at 194
                IF lives >= 2 THEN
                    IF bomb_y(c) >= 194 AND bomb_y(c) < 202 THEN hit_detected = 1
                END IF

                ' Top bucket row (only if 3 lives): centered at 176
                IF lives >= 3 THEN
                    IF bomb_y(c) >= 176 AND bomb_y(c) < 184 THEN hit_detected = 1
                END IF
            END IF

            IF hit_detected = 1 THEN
                bomb_s(c) = 0   
                GOSUB splash_sfx
                IF score < 9999 THEN score = score + 1
                GOSUB add_score_point

                ' --- SPLASH TRIGGER ---
                ' Determine which bucket row was hit (matching the ranges above)
                IF bomb_y(c) >= 212 AND bomb_y(c) < 220 THEN r = 0
                IF bomb_y(c) >= 194 AND bomb_y(c) < 202 THEN r = 1
                IF bomb_y(c) >= 176 AND bomb_y(c) < 184 THEN r = 2

                splash_x(r) = bomb_x(c) - x_bucket
                splash_y(0) = 212 - 8
                splash_y(1) = 194 - 8
                splash_y(2) = 176 - 8
                splash_t(r) = 12   ' lasts 12 frames

                
            END IF

            IF bomb_y(c) >= 230 THEN
                bomb_s(c) = 0       
                GOSUB bomb_missed_sfx
                lives = lives - 1
                IF lives < 1 THEN 
                    lives = 0

                    ' Clear splash before game over
                    FOR r = 0 TO 2
                        splash_t(r) = 0
                        SPRITE 4 + r, 255, 0, 0, 0
                    NEXT r
                    GOSUB game_over_sfx
                    GOTO game_over_screen
                END IF
                WAIT

                ' Clear splash before life-lost screen
                FOR r = 0 TO 2
                    splash_t(r) = 0
                    SPRITE 4 + r, 255, 0, 0, 0
                NEXT r

                GOTO life_lost_draw
            END IF
        END IF
    NEXT c

    ' If wave is done, clear splash and go to wave complete
    IF bombs_remaining = 0 AND active_bombs = 0 THEN
        GOSUB wave_complete_sfx
        FOR r = 0 TO 2
            splash_t(r) = 0
            SPRITE 4 + r, 255, 0, 0, 0
        NEXT r
        GOTO wave_completed
    END IF

    ' --- DRAWING ---
    FOR c = 20 TO 39 : SPRITE c, 255, 0, 0, 0 : NEXT c
    FOR c = 48 TO 63 : SPRITE c, 255, 0, 0, 0 : NEXT c

    GOSUB draw_bomber_sub

    ' -- DETERMINE PRIORITY ROTATION --
    ' We rotate which row gets the "low" (high priority) sprite indices
    ' using the rng_seed as a frame counter.
    ' This was designed to help with flicker, but honestly doesn't really help much.
    temp_val = rng_seed % 3
    IF temp_val = 0 THEN
        s_row1 = 24
        s_row2 = 27
        s_row3 = 30
        s_ex1 = 33
        s_ex2 = 34
        s_ex3 = 35
    ELSEIF temp_val = 1 THEN
        s_row1 = 30
        s_row2 = 24
        s_row3 = 27
        s_ex1 = 35
        s_ex2 = 33
        s_ex3 = 34
    ELSE
        s_row1 = 27
        s_row2 = 30
        s_row3 = 24
        s_ex1 = 34
        s_ex2 = 35
        s_ex3 = 33
    END IF

    ' -- DRAW BUCKET ROWS --
    col1_x = x_bucket
    col2_x = x_bucket + 8
    col3_x = x_bucket + 16
    col4_x = x_bucket + 24

    b_vis_1 = 212
    IF lives >= 2 THEN
        b_vis_2 = 194
    ELSE
        b_vis_2 = 255
    END IF
    IF lives >= 3 THEN
        b_vis_3 = 176
    ELSE
        b_vis_3 = 255
    END IF

    ' Draw Row 1
    SPRITE s_row1, b_vis_1, col1_x, 136, 3
    SPRITE s_row1 + 1, b_vis_1, col2_x, 136, 3
    IF difficulty < 2 THEN
        SPRITE s_row1 + 2, b_vis_1, col3_x, 136, 3
    ELSE
        SPRITE s_row1 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 THEN
        SPRITE s_ex1, b_vis_1, col4_x, 136, 3
    ELSE
        SPRITE s_ex1, 255, 0, 0, 0
    END IF

    ' Draw Row 2
    SPRITE s_row2, b_vis_2, col1_x, 136, 3
    SPRITE s_row2 + 1, b_vis_2, col2_x, 136, 3
    IF difficulty < 2 AND b_vis_2 < 255 THEN
        SPRITE s_row2 + 2, b_vis_2, col3_x, 136, 3
    ELSE
        SPRITE s_row2 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 AND b_vis_2 < 255 THEN
        SPRITE s_ex2, b_vis_2, col4_x, 136, 3
    ELSE
        SPRITE s_ex2, 255, 0, 0, 0
    END IF

    ' Draw Row 3
    SPRITE s_row3, b_vis_3, col1_x, 136, 3
    SPRITE s_row3 + 1, b_vis_3, col2_x, 136, 3
    IF difficulty < 2 AND b_vis_3 < 255 THEN
        SPRITE s_row3 + 2, b_vis_3, col3_x, 136, 3
    ELSE
        SPRITE s_row3 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 AND b_vis_3 < 255 THEN
        SPRITE s_ex3, b_vis_3, col4_x, 136, 3
    ELSE
        SPRITE s_ex3, 255, 0, 0, 0
    END IF

    ' Splash animation follows bucket
    FOR r = 0 TO 2
        IF splash_t(r) > 0 THEN
            SPRITE 4 + r, splash_y(r), x_bucket + splash_x(r), 140, 3
            splash_t(r) = splash_t(r) - 1
        ELSE
            SPRITE 4 + r, 255, 0, 0, 0
        END IF
    NEXT r

    ' Draw Score
    GOSUB redraw_score

    FOR c = 0 TO 7
        IF bomb_s(c) = 1 THEN
            SPRITE 40 + c, bomb_y(c), bomb_x(c), 138, 1
        ELSE
            SPRITE 40 + c, 255, 0, 0, 0
        END IF
    NEXT c

    WAIT

    GOTO game_loop

' =========================================================================
'  MUSIC DATA: NOTE TABLE
' =========================================================================

note_table_low:
    DATA $F1, $D5, $BC, $A8, $8F, $7A, $68, $5A, $4E, $45, $3D, $36

note_table_high:
    DATA $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $03, $03

' =========================================================================
'  MUSIC DATA: TITLE THEME SEQUENCES
' =========================================================================

title_intro_melody:
    DATA 7, 9, 12, 11

title_intro_harmony:
    DATA 4, 7, 9, 7

title_intro_bass:
    DATA 0, 0, 0, 0

title_intro_drums:
    DATA 2,1,2,1

title_intro_duration:
    DATA 18,18,18,18

title_melody:
    DATA 0,2,4,5,7,5,4,2,0,2,4,7,5,4,2,0

title_harmony:
    DATA 7,9,11,0,2,0,11,9,7,9,11,2,0,11,9,7

title_bass:
    DATA 0,0,7,7,0,0,7,7,0,0,7,7,0,0,7,7

title_drums:
    DATA 2,0,1,0,2,0,1,0,2,0,1,0,2,1,2,1

title_duration:
    DATA 12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12

title_melody_b:
    DATA 4,5,7,9,11,9,7,5,7,9,11,12,11,9,7,5

title_harmony_b:
    DATA 7,9,11,12,12,11,9,7,9,11,12,14,12,11,9,7

title_bass_b:
    DATA 0,0,5,5,7,7,9,9,5,5,7,7,9,9,11,11

title_drums_b:
    DATA 2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1

title_duration_b:
    DATA 14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14

audio_silence_all:
    ' Square 1
    POKE $4000, $30
    POKE $4001, $00
    POKE $4002, $00
    POKE $4003, $00

    ' Square 2
    POKE $4004, $30
    POKE $4005, $00
    POKE $4006, $00
    POKE $4007, $00

    ' Triangle
    POKE $4008, $80
    POKE $400A, $00
    POKE $400B, $00

    ' Noise
    POKE $400C, $00
    POKE $400E, $00
    POKE $400F, $00

    RETURN

splash_sfx:
    ' Ensure noise channel is enabled
    POKE $4015, $0F

    ' --- Start of splash ---
    ' Volume = 0x1F (loud), constant envelope
    POKE $400C, $1F

    ' Start with a mid‑pitch noise (watery)
    POKE $400E, $84

    ' Trigger the noise channel (critical)
    POKE $400F, $FF

    ' Hold the initial burst for a frame
    WAIT

    ' Slightly lower pitch (falling splash)
    POKE $400E, $06
    WAIT

    ' Lower again (tail of splash)
    POKE $400E, $08
    WAIT

    ' Fade out
    POKE $400C, $0C
    WAIT

    ' Silence
    POKE $400C, $00
    RETURN

bomb_missed_sfx:
    ' Enable channels
    POKE $4015, $0F

    ' --- Initial blast ---
    POKE $400C, $1F        ' max volume
    POKE $400E, $80        ' short-mode noise, high pitch
    POKE $400F, $20        ' trigger with a longer length
    WAIT
    WAIT

    ' --- Mid burst ---
    POKE $400E, $88
    WAIT
    WAIT

    ' --- Tail rumble ---
    POKE $400E, $8F
    WAIT
    WAIT

    ' --- Fade ---
    POKE $400C, $0C
    WAIT
    WAIT

    ' Silence
    POKE $400C, $00
    RETURN

wave_complete_sfx:
    ' Enable channels
    POKE $4015, $0F

    ' First note (high)
    POKE $4000, $BF       ' square 1, constant volume
    POKE $4002, $4E       ' B5 low byte
    POKE $4003, $03       ' B5 high byte
    WAIT
    WAIT

    ' Second note (higher)
    POKE $4002, $45       ' C6 low byte
    POKE $4003, $03       ' C6 high byte
    WAIT
    WAIT

    ' Silence
    POKE $4000, $30
    RETURN

game_over_sfx:
    ' Enable channels
    POKE $4015, $0F

    ' Note 1 (mid)
    POKE $4000, $BF
    POKE $4002, $A8       ' D5-ish
    POKE $4003, $02
    WAIT
    WAIT

    ' Note 2 (lower)
    POKE $4002, $BC       ' C#5-ish
    POKE $4003, $02
    WAIT
    WAIT

    ' Note 3 (lowest)
    POKE $4002, $D5       ' B4-ish
    POKE $4003, $02
    WAIT
    WAIT

    ' Silence
    POKE $4000, $30
    RETURN

' ---------------------------------------------------------
'  SUBROUTINE: ADD SCORE POINT
' ---------------------------------------------------------
add_score_point:
    ' Increment total score tracker (for high score comparison later)
    IF score_val < 32767 THEN
        score_val = score_val + 1
    END IF

    ' Ripple Carry Logic for 5 Digits
    d_ones = d_ones + 1
    IF d_ones > 9 THEN
        d_ones = 0
        d_tens = d_tens + 1
        IF d_tens > 9 THEN
            d_tens = 0
            d_hund = d_hund + 1
            IF d_hund > 9 THEN
                d_hund = 0
                d_thou = d_thou + 1
                ' Extra Life every 1,000 points
                IF lives < 3 THEN
                    lives = lives + 1
                END IF
                IF d_thou > 9 THEN
                    d_thou = 0
                    d_tthou = d_tthou + 1
                    IF d_tthou > 9 THEN
                        ' Hard Cap at 99,999
                        d_tthou = 9
                        d_thou = 9
                        d_hund = 9
                        d_tens = 9
                        d_ones = 9
                    END IF
                END IF
            END IF
        END IF
    END IF
    RETURN

' ---------------------------------------------------------
'  SUBROUTINE: DRAW BOMBER
' ---------------------------------------------------------
draw_bomber_sub:
    IF bomber_dir = 1 THEN 
        bomber_attr = 0
        SPRITE 0, y_bomber, x_bomber, 128, bomber_attr
        SPRITE 1, y_bomber, x_bomber + 8, 130, bomber_attr
        SPRITE 2, y_bomber + 16, x_bomber, 132, bomber_attr
        SPRITE 3, y_bomber + 16, x_bomber + 8, 134, bomber_attr
    ELSE
        bomber_attr = 64
        SPRITE 0, y_bomber, x_bomber, 130, bomber_attr
        SPRITE 1, y_bomber, x_bomber + 8, 128, bomber_attr
        SPRITE 2, y_bomber + 16, x_bomber, 134, bomber_attr
        SPRITE 3, y_bomber + 16, x_bomber + 8, 132, bomber_attr
    END IF
    RETURN

' ---------------------------------------------------------
'  SUBROUTINE: WAVE COMPLETED
' ---------------------------------------------------------
wave_completed:
    FOR r = 0 TO 2
        splash_t(r) = 0
        SPRITE 4 + r, 255, 0, 0, 0
    NEXT r
    FOR c = 0 TO 7
        bomb_s(c) = 0
        SPRITE 40 + c, 255, 0, 0, 0
    NEXT c
    GOSUB draw_bomber_sub

    ' Display using the wave variable directly
    PRINT AT 898, "WAVE "
    PRINT AT 903, wave
    PRINT AT 905, " COMPLETE! - PRESS A"

    WAIT

    WHILE 1
        WAIT
        IF cont1.button THEN
            PRINT AT 896, "                                "
            GOSUB redraw_score
            wave = wave + 1
            GOTO start_wave
        END IF
    WEND

' ---------------------------------------------------------
'  SUBROUTINE: LIFE LOST
' ---------------------------------------------------------
life_lost_draw:
    FOR c = 0 TO 7
        IF bomb_s(c) = 1 THEN 
            SPRITE 40 + c, bomb_y(c), bomb_x(c), 138, 1 
        ELSE 
            SPRITE 40 + c, 255, 0, 0, 0
        END IF
    NEXT c
    GOSUB draw_bomber_sub

    temp_val = rng_seed % 3
    IF temp_val = 0 THEN
        s_row1 = 24
        s_row2 = 27
        s_row3 = 30
        s_ex1 = 33
        s_ex2 = 34
        s_ex3 = 35
    ELSEIF temp_val = 1 THEN
        s_row1 = 30
        s_row2 = 24
        s_row3 = 27
        s_ex1 = 35
        s_ex2 = 33
        s_ex3 = 34
    ELSE
        s_row1 = 27
        s_row2 = 30
        s_row3 = 24
        s_ex1 = 34
        s_ex2 = 35
        s_ex3 = 33
    END IF

    col1_x = x_bucket
    col2_x = x_bucket + 8
    col3_x = x_bucket + 16
    col4_x = x_bucket + 24

    b_vis_1 = 212
    IF lives >= 2 THEN
        b_vis_2 = 194
    ELSE
        b_vis_2 = 255
    END IF
    IF lives >= 3 THEN
        b_vis_3 = 176
    ELSE
        b_vis_3 = 255
    END IF

    ' Draw Row 1
    SPRITE s_row1, b_vis_1, col1_x, 136, 3
    SPRITE s_row1 + 1, b_vis_1, col2_x, 136, 3
    IF difficulty < 2 THEN
        SPRITE s_row1 + 2, b_vis_1, col3_x, 136, 3
    ELSE
        SPRITE s_row1 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 THEN
        SPRITE s_ex1, b_vis_1, col4_x, 136, 3
    ELSE
        SPRITE s_ex1, 255, 0, 0, 0
    END IF

    ' Draw Row 2
    SPRITE s_row2, b_vis_2, col1_x, 136, 3
    SPRITE s_row2 + 1, b_vis_2, col2_x, 136, 3
    IF difficulty < 2 AND b_vis_2 < 255 THEN
        SPRITE s_row2 + 2, b_vis_2, col3_x, 136, 3
    ELSE
        SPRITE s_row2 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 AND b_vis_2 < 255 THEN
        SPRITE s_ex2, b_vis_2, col4_x, 136, 3
    ELSE
        SPRITE s_ex2, 255, 0, 0, 0
    END IF

    ' Draw Row 3
    SPRITE s_row3, b_vis_3, col1_x, 136, 3
    SPRITE s_row3 + 1, b_vis_3, col2_x, 136, 3
    IF difficulty < 2 AND b_vis_3 < 255 THEN
        SPRITE s_row3 + 2, b_vis_3, col3_x, 136, 3
    ELSE
        SPRITE s_row3 + 2, 255, 0, 0, 0
    END IF
    IF difficulty = 0 AND b_vis_3 < 255 THEN
        SPRITE s_ex3, b_vis_3, col4_x, 136, 3
    ELSE
        SPRITE s_ex3, 255, 0, 0, 0
    END IF

    GOTO life_lost_pause

' ---------------------------------------------------------
'  SUBROUTINE: LIFE LOST PAUSE
' ---------------------------------------------------------
life_lost_pause:
    FOR c = 0 TO 7
        bomb_s(c) = 0
        SPRITE 40 + c, 255, 0, 0, 0
    NEXT c
    FOR r = 0 TO 2
        splash_t(r) = 0
        SPRITE 4 + r, 255, 0, 0, 0
    NEXT r
    GOSUB draw_bomber_sub

    ' UI on Row 28
    PRINT AT 901, "BOMB MISSED! - PRESS A"

    WHILE 1
        WAIT
        IF cont1.button THEN 
            PRINT AT 896, "                                "
            GOSUB redraw_score
            GOTO start_wave
        END IF
    WEND

' ---------------------------------------------------------
'  SUBROUTINE: NEW GAME PAUSE
' ---------------------------------------------------------
new_game_pause:
    FOR r = 0 TO 2
        splash_t(r) = 0
        SPRITE 4 + r, 255, 0, 0, 0
    NEXT r
    FOR c = 0 TO 7
        bomb_s(c) = 0
        SPRITE 40 + c, 240, 0, 0, 0
    NEXT c
    GOSUB draw_bomber_sub

    ' Print to Row 28
    PRINT AT 900, "READY? PRESS A TO START"

    WHILE 1
        WAIT
        IF cont1.button THEN
            ' Clear Row 28
            PRINT AT 896, "                                "
            GOSUB redraw_score
            RETURN
        END IF
    WEND

' ---------------------------------------------------------
'  SUBROUTINE: GAME OVER
' ---------------------------------------------------------
game_over_screen:
    FOR c = 0 TO 63
        SPRITE c, 255, 0, 0, 0
    NEXT c

    PRINT AT 896, "                                "
    GOSUB redraw_score
    PRINT AT 907, "GAME OVER"
    
    ' Save the current wave
    last_wave = wave
    
    ' Manual Digit-by-Digit High Score Comparison
    ' (We only update high score if current score is higher)
    r = 0 ' Flag for "is current score higher?"
    IF d_tthou > h_tthou THEN r = 1
    IF d_tthou = h_tthou AND d_thou > h_thou THEN r = 1
    IF d_tthou = h_tthou AND d_thou = h_thou AND d_hund > h_hund THEN r = 1
    IF d_tthou = h_tthou AND d_thou = h_thou AND d_hund = h_hund AND d_tens > h_tens THEN r = 1
    IF d_tthou = h_tthou AND d_thou = h_thou AND d_hund = h_hund AND d_tens = h_tens AND d_ones > h_ones THEN r = 1

    IF r = 1 THEN
        ' Update High Score Digit Variables
        h_tthou = d_tthou
        h_thou = d_thou
        h_hund = d_hund
        h_tens = d_tens
        h_ones = d_ones
    END IF
    
    WHILE 1
        WAIT
        IF cont1.button THEN
            GOTO title_screen
        END IF
    WEND
    
' ---------------------------------------------------------
'  SUBROUTINE: REFRESH GAME SCREEN
'  Wipes everything and redraws the clean cityscape
' ---------------------------------------------------------
refresh_game_screen:
    SCREEN DISABLE
    CLS 
    ' Redraw the Sky and Top of Buildings
    FOR r = 0 TO 1
        PRINT AT r * 32, "***********************(((******"
    NEXT r
    PRINT AT 64,  "****(((((*(((*((((*****( (*((((("
    PRINT AT 96,  "****( ( (*( (*( ((*****(((*( ( ("
    PRINT AT 128, "(((*(((((*(((*((((*(((*(((*((((("
    PRINT AT 160, "( (*( ( (*( (*((((*(((*(((*( ((("
    PRINT AT 192, "(((*(((((*(((*((((*(((*(((*((((("

    ' Redraw the Main Building Area (The green area)
    FOR r = 7 TO 27
        PRINT AT r * 32, "))))))))))))))))))))))))))))))))"
    NEXT r
    
    SCREEN ENABLE
    RETURN

redraw_score:
    ' All digits on Row 1 (Y=8)
    ' Ten Thousands
    SPRITE 15, 8, 208, 160 + (d_tthou * 2), 2
    ' Thousands
    SPRITE 16, 8, 216, 160 + (d_thou * 2), 2
    ' Hundreds
    SPRITE 17, 8, 224, 160 + (d_hund * 2), 2
    ' Tens
    SPRITE 18, 8, 232, 160 + (d_tens * 2), 2
    ' Ones
    SPRITE 19, 8, 240, 160 + (d_ones * 2), 2
    RETURN

' -- GRAPHICS --
    CHRROM 0

' == BACKGROUND NUMBERS (48+) ==
    CHRROM PATTERN 48
    ' 0
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"
    ' 1
    BITMAP "...33..." 
    BITMAP "..333..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP ".333333."
    BITMAP "........"
    ' 2
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP ".....33." 
    BITMAP "...33..." 
    BITMAP "..33...." 
    BITMAP "33......" 
    BITMAP "3333333."
    BITMAP "........"
    ' 3
    BITMAP "333333.." 
    BITMAP "....33.." 
    BITMAP "...33..." 
    BITMAP "....33.." 
    BITMAP ".....33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"
    ' 4
    BITMAP "...333.." 
    BITMAP "..333..." 
    BITMAP ".33.3..." 
    BITMAP "33..3..." 
    BITMAP "3333333." 
    BITMAP "....3..." 
    BITMAP "....3..."
    BITMAP "........"
    ' 5
    BITMAP "3333333." 
    BITMAP "33......" 
    BITMAP "333333.." 
    BITMAP ".....33." 
    BITMAP ".....33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"
    ' 6
    BITMAP ".33333.." 
    BITMAP "33......" 
    BITMAP "333333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"
    ' 7
    BITMAP "3333333." 
    BITMAP "33...33." 
    BITMAP "...33..." 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "..33...."
    BITMAP "........"
    ' 8
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.." 
    BITMAP "........"
    ' 9
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP ".333333." 
    BITMAP ".....33." 
    BITMAP "....33.." 
    BITMAP "...33..." 
    BITMAP ".333...."
    BITMAP "........"

    ' Pattern 58: COLON (Grey on Black)
    BITMAP "........" 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "........" 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "........" 
    BITMAP "........"

    ' PATTERN 127: COPYRIGHT SYMBOL (Uses 3 = Grey)
    CHRROM PATTERN 127
    BITMAP ".33333.." 
    BITMAP "3.....3." 
    BITMAP "3.333.3." 
    BITMAP "3.3...3." 
    BITMAP "3.3...3." 
    BITMAP "3.333.3." 
    BITMAP "3.....3." 
    BITMAP ".33333.."

    ' PATTERN 200: THE TITLE LOGO BLOCK (Uses 1 = ORANGE)
    CHRROM PATTERN 200
    BITMAP "11111111" 
    BITMAP "1......1" 
    BITMAP "1.1..1.1" 
    BITMAP "1..11..1" 
    BITMAP "1..11..1" 
    BITMAP "1.1..1.1" 
    BITMAP "1......1" 
    BITMAP "11111111"

    ' PATTERN 201: SOLID ORANGE BLOCK (Uses 1 = ORANGE)
    CHRROM PATTERN 201
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111"

    ' == SPRITES (128+) ==
    CHRROM PATTERN 128

    ' Bomber
    BITMAP "....1111" 
    BITMAP "...11111" 
    BITMAP "...11111" 
    BITMAP "...11111"
    BITMAP "11111..1" 
    BITMAP "11111111" 
    BITMAP "33333333" 
    BITMAP "....333."

    BITMAP "....333." 
    BITMAP "....3333" 
    BITMAP "....333." 
    BITMAP "....3..3"
    BITMAP ".....333" 
    BITMAP ".....333" 
    BITMAP ".....111" 
    BITMAP "...22222"

    BITMAP "1111...." 
    BITMAP "11111..." 
    BITMAP "11111..." 
    BITMAP "11111..."
    BITMAP "1..11111" 
    BITMAP "11111111" 
    BITMAP "33333333" 
    BITMAP ".333...."

    BITMAP ".333...." 
    BITMAP "3333...." 
    BITMAP ".333...." 
    BITMAP "3..3...."
    BITMAP "333....." 
    BITMAP "333....." 
    BITMAP "111....." 
    BITMAP "22222..."

    BITMAP "11111111" 
    BITMAP "22222222" 
    BITMAP "11111111" 
    BITMAP "22222222"
    BITMAP "11..1111" 
    BITMAP "22..2222" 
    BITMAP "11..1111" 
    BITMAP "22..2222"

    BITMAP "11..1111" 
    BITMAP "22..2222" 
    BITMAP "11..1111" 
    BITMAP "22..2222"
    BITMAP "33..1111" 
    BITMAP "33......" 
    BITMAP "..3....." 
    BITMAP "........"

    BITMAP "11111111" 
    BITMAP "22222222" 
    BITMAP "11111111" 
    BITMAP "22222222"
    BITMAP "1111..11" 
    BITMAP "2222..22" 
    BITMAP "1111..11" 
    BITMAP "2222..22"

    BITMAP "1111..11" 
    BITMAP "2222..22" 
    BITMAP "1111..11" 
    BITMAP "2222..22"
    BITMAP "1111..33" 
    BITMAP "......33" 
    BITMAP ".....3.." 
    BITMAP "........"

    ' BUCKET (136/137)
    ' Uses Palette 3 (2s=Blue $12, 3s=Brown $07)
    ' 136 = Top Sprite (Water + rim/body)
    BITMAP "22222222" ' Row 0
    BITMAP "22222222" ' Row 1
    BITMAP "33333333" ' Row 6
    BITMAP "33333333" ' Row 7
    BITMAP "33333333" ' Row 4
    BITMAP "33333333" ' Row 5
    BITMAP "33333333" ' Row 6
    BITMAP "33333333" ' Row 7

    ' 137 = Bottom Sprite (Bucket continuation / can be empty if not needed)
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 

    ' BOMB (138)
    BITMAP "...3...." 
    BITMAP "...2...." 
    BITMAP "..1111.." 
    BITMAP ".111111."
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP ".111111." 
    BITMAP "..1111.."

    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' SPLASH FRAME A (140)
    CHRROM PATTERN 140
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "2......2"
    BITMAP "..2..2.."
    BITMAP ".222222."
    BITMAP "..2222.."
    BITMAP "...22..."

    ' SPLASH FRAME B (141) 
    CHRROM PATTERN 141
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"
    BITMAP "........"

    ' PATTERN 146: CURSOR 
    ' Uses color 3 (Light Grey in Palette 3)
    CHRROM PATTERN 146
    BITMAP "........"
    BITMAP "..3333.."
    BITMAP ".333333."
    BITMAP ".333333."
    BITMAP ".333333."
    BITMAP ".333333."
    BITMAP "..3333.."
    BITMAP "........"

    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' PATTERN 40: BUILDING BLOCK (SOLID 3s = DARK GREY)
    CHRROM PATTERN 40
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"
    BITMAP "33333333"

    ' PATTERN 41: FLOOR MAIN AREA (SOLID 1s = GREEN)
    CHRROM PATTERN 41
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 
    BITMAP "11111111" 

    ' PATTERN 42: DARK BLUE SKY (SOLID 2s = BLUE)
    CHRROM PATTERN 42
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 
    BITMAP "22222222" 

    ' PATTERN 160: NUMBERS FOR SPRITES (Uses 3s = GREY)
    ' ** FIXED **: Added blank spacers between digits to align with *2 logic
    CHRROM PATTERN 160
    ' 0
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 1
    BITMAP "...33..." 
    BITMAP "..333..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP "...33..." 
    BITMAP ".333333."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 2
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP ".....33." 
    BITMAP "...33..." 
    BITMAP "..33...." 
    BITMAP "33......" 
    BITMAP "3333333."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 3
    BITMAP "333333.." 
    BITMAP "....33.." 
    BITMAP "...33..." 
    BITMAP "....33.." 
    BITMAP ".....33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 4
    BITMAP "..333..." 
    BITMAP ".33.3..." 
    BITMAP "33..3..." 
    BITMAP "3333333." 
    BITMAP "....3..." 
    BITMAP "....3..." 
    BITMAP "....3..."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 5
    BITMAP "3333333." 
    BITMAP "33......" 
    BITMAP "333333.." 
    BITMAP ".....33." 
    BITMAP ".....33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 6
    BITMAP ".33333.." 
    BITMAP "33......" 
    BITMAP "333333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 7
    BITMAP "3333333." 
    BITMAP "33...33." 
    BITMAP "...33..." 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "..33...." 
    BITMAP "..33...."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 8
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP "33...33." 
    BITMAP ".33333.." 
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"

    ' 9
    BITMAP ".33333.." 
    BITMAP "33...33." 
    BITMAP ".333333." 
    BITMAP ".....33." 
    BITMAP "....33.." 
    BITMAP "...33..." 
    BITMAP ".333...."
    BITMAP "........"

    ' Spacer
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........" 
    BITMAP "........"




