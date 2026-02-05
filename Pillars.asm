#################  ###################
# This file contains the implementation of Pillars.
# Student 1: Mustafa Majeed

######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

#Citations:
#https://weinman.cs.grinnell.edu/courses/CSC211/2020F/labs/mips-basics/play-song.asm #I used this code to learn how to play music/sounds in my mips program.


    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
    
#6 gem colors    
gem_colors:
    .word 0xff0000  # red
    .word 0xff8000  # orange
    .word 0xffff00  # yellow
    .word 0x00ff00  # green
    .word 0x0000ff  # blue
    .word 0x8000ff  # purple
    
#SPECIAL COLORS
bomb_col_color: .word 0xFFFFFF   # White (Column Bomb), this is the color which deletes the whole row 
    
#game sounds are stored here. 

sound_move:     .word 70, 50, 115, 100    # (Click)
sound_shuffle:  .word 75, 75, 12, 127    # (Light)
sound_down:     .word 61, 100, 116, 120   # (Thud)
sound_match:    .word 84, 400, 9, 127     # (Chime)
sound_gameover: .word 35, 1000, 55, 127   # Crash)

##############################################################################
# Mutable Data
##############################################################################

board: #board is 6 x 15 = 90 cells, 90 * 4 = 360
    .space 360
matches:
    .space 360 #used to find matches, it is an exact replica of the original array, but stores 1, where there are matches. for deletion.

#starting column positions
current_col_x:
    .word 4 #starting position row
current_col_y:
    .word 2 #starting position column 
current_col_clr:
    .space 12 #3 words for 3 colors. 
next_col_clr:
    .space 12 #next column, stores the next column color for the next part
    
number_of_matches: .word 0 #this is how we increase the gravity. 

gravity_timer: .word 0 
gravity_speed: .word 60 #you want it to fall once per second (60 fps), how fast they fall

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal screen_setup #setup the walls
    jal init_column #setup the initial column.
    jal init_column #calls it twice, so we have initial column and you have a next column. 
    jal draw_current_column #draw the current column.    

game_loop:

    li 	$v0, 32 #60 fps sleep
	li 	$a0, 17 #~16.6 ms
	syscall #this is the 60 fps counter
	
	lw $t0, gravity_timer #this is an iterative variable, which tells how many itertations bave been done for the loop
	addi $t0, $t0, 1 #timer ++
	
	lw $t1, gravity_speed #and if 60 things are done, you drop one. 
	
	blt $t0, $t1, skip_gravity
	
	sw $zero, gravity_timer #reset_timer
	
	jal fall_step #this drops it one.
	jal redraw_frame #rederaw the board. 
	
skip_gravity: #we come here, if 60 loops are not done.
    sw $t0, gravity_timer #save new value. 
	jal keyboard_input #handle all the keyboard input
	
	#todo: add gravity here, using landing. 
	
	jal redraw_frame #then redraw the screen. 
	
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop
    
    
screen_setup: #original screen setup
#This function draws all the walls. By doing multiple loops using the $t0, $t1 registers and using the draw_cell function. 

#inputs = $t2, which iterative variable.
 
    addi $sp, $sp, -4 # save return address
    sw $ra, 0($sp)
    li $a2, 0xff00ff #wall color
    
    li $t0, 0 #initialize iterative.


left_wall: bgt $t0, 15, right_wall_setup #stop at row > 15

    add $a0, $zero, $t0 #row
    li $a1, 0 #column. 
    jal draw_cell
    addi $t0, $t0, 1
    
    j left_wall

right_wall_setup:
     li  $t0, 0   # row = 0
     
right_wall: bgt $t0, 15, bottom_wall_setup #stop at row > 15

    add $a0, $zero, $t0 #row
    li $a1, 7 #column. 
    #li $a2, 0xffffff   #color
    jal draw_cell
    addi $t0, $t0, 1
    j right_wall

bottom_wall_setup: 
    li $t1, 0 #col = 0
    
bottom_wall: bgt $t1, 7, end_screen_setup
    li $a0, 15 #row = 12
    add $a1, $zero, $t1
   # li $a2, 0xffffff   #color
    
    jal draw_cell
    addi $t1, $t1, 1
    j bottom_wall

end_screen_setup:
    # restore return address
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

draw_cell:
#inputs: a0 = row, a1 = col, a2 = color
#output: draws a cell on the bitmap address. 

    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  get_cell_address    # you get the cell_adress, from your arguments and you save it in v0
    sw   $a2, 0($v0)         # store color at that address, which is how we draw. 

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

get_cell_address:
    # inputs:  a0 = row, a1 = col
    # output:  v0 = address of that cell in the bitmap

    lw   $t5, ADDR_DSPL      # t5 = base address 0x10008000
    
    sll  $t6, $a0, 5         # row * 32 (since 2^5 = 32), row_offset_units = row * 32

    addu $t6, $t6, $a1    # add column: row*32 + col
    
    sll  $t6, $t6, 2     # convert units to bytes: (row*32 + col) * 4, we just use the sll by 2. 

    addu $v0, $t5, $t6     # final address, original address + all the math

    jr   $ra #and then you return.


init_column:
#This function handles just genrating the random columns, and saving them. NO need for arguments. 

    # Fills current_col_clr[0-2] with random colours from gem_colors[0-5]
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    la $t0, next_col_clr   #get the adress for the next_col array
    la  $t2, current_col_clr #get the adress for the current_col_array
    
    lw $t4, 0($t0) #you get color from next and save it into first of current
    sw $t4, 0($t2) #repeat this process for each gem.
    
    lw $t4, 4($t0) 
    sw $t4, 4($t2)
    
    lw $t4, 8($t0) 
    sw $t4, 8($t2)

    li   $t1, 0   #reset $t1 = 0, its our iterative variable.
    
init_column_loop:
    beq  $t1, 3, init_column_done #run it 3 times for 3 gems. 
    
    # 1. Roll for Probability (0-20)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 10
    syscall
    move $t2, $a0
    
    # Check for Column Bomb If Roll == 7, we skip to spawn_col_bomb which adds that to our next_array.
    li   $t3, 7
    beq  $t2, $t3, spawn_col_bomb

    # Normal Gem (Roll 0-5)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 6
    syscall
    
    # Load Normal Color
    la   $t3, gem_colors
    sll  $t4, $a0, 2        # index * 4
    addu $t4, $t3, $t4      # addr + offset
    lw   $t5, 0($t4)        # Load the color value
    j    save_gem_to_next

spawn_col_bomb:
    lw   $t5, bomb_col_color    # load the color pink
    j    save_gem_to_next


save_gem_to_next:
    sw   $t5, 0($t0)            # Save color to next_col_clr[i]
    
    # Increment Variables
    addi $t0, $t0, 4            # Next word in array next
    addi $t1, $t1, 1            # i++
    j    init_column_loop

    
init_column_done:
    lw $ra, 0($sp) #going back to our stack. 
    addi $sp, $sp, 4
    jr $ra
    
draw_current_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    lw $t0, current_col_x #x
    lw $t1, current_col_y #y
    la $t2, current_col_clr #colors we will draw. pulled from current_col_clr[]
    
    li $t3, 0 #iterative
    
draw_current_column_loop:
    beq $t3,3, draw_current_column_loop_end #repeat this for 3 gems.
    
    lw $t4, 0($t2) #gem_color at i
    
    addu $a0, $t1, $t3 #row = y + i
    move $a1, $t0 #col = x
    move $a2, $t4 #color
    
    jal draw_cell #draw that cell
    
    addi $t2, $t2, 4  # move up one color.
    
    addi $t3, $t3, 1 #move up iterative
    
    j draw_current_column_loop
    
draw_current_column_loop_end:
    lw   $ra, 0($sp) #take us back 
    addi $sp, $sp, 4
    jr   $ra

keyboard_input:   

    addi $sp, $sp, -4
    sw   $ra, 0($sp)   
    
    lw $t7, ADDR_KBRD               # $t7 = base address for keyboard
    lw $t8, 0($t7)                  # Load first word from keyboard
    beq $t8, 0, keyboard_done   # if no key is clicked don't do anything 
    lw   $t8, 4($t7) # key is clicked.
    
    li  $t9, 'q'
    beq $t8, $t9, q_click #check if user is trying to quit. 
    li  $t9, 'w'
    #All the other movement keys. 
    beq $t8, $t9, w_click 
    li  $t9, 'a'
    beq $t8, $t9, a_click 
    li  $t9, 's'
    beq $t8, $t9, s_click 
    li  $t9, 'd'
    beq $t8, $t9, d_click 
    li  $t9, 'p'
    #Pause Key Check
    beq $t8, $t9, p_click 
    
    j keyboard_done

w_click:
  
    la $s7, sound_shuffle #first play shufffle sounnd. load into argument variable and call the function.
    jal play_sound
    
    la $t0, current_col_clr 
    
    #Simple Flipping colors logic.
    lw $t1, 0($t0) #old top color:
    lw $t2, 4($t0) #old middle color:
    lw $t3, 8($t0) #old bottom color:
    
    sw   $t2, 0($t0)  # top = old middle
    sw   $t3, 4($t0)  # middle = old bottom
    sw   $t1, 8($t0)  # bottom = old top
    
    j keyboard_done
    
a_click:

    la $s7, sound_move #Play sound then do movement.
    jal play_sound
    
    lw $t0, current_col_x   # t0 = x
    lw $t3, current_col_y  #t3 = y
     
    #checking wall collision
    li   $t1, 1               # Left Wall
    beq  $t0, $t1, keyboard_done   # check if we at wall, then dont move
    
    #now we check collision with other columns
    
    #You check the 3rd gem, because if it doesn't colide you don't have to check the rest.
    addi $a0, $t3, 2 #y row, 2 down
    addi $a1, $t0, -2 #x column, 1 left
    
    jal  board_get   # returns the color at that part of the board. 

    bne  $v0, $zero, keyboard_done #if v0 != 0 (meaning occupied), we just skip ahead.

    #save our new x, if movement possible
    addi $t0, $t0, -1         # x = x - 1
    sw   $t0, current_col_x

    j    keyboard_done

d_click:
    
    la $s7, sound_move #same logic
    jal play_sound
    
    lw $t0, current_col_x   # t0 = x
    lw $t3, current_col_y #t3  = y

    #checking wall collision
    li   $t1, 6               # rightmost playable col
    beq  $t0, $t1, keyboard_done   # already at 6, dont move
    
   #now we check collision with other columns
   #now we check 3rd gem but towards the right
    addi $a0, $t3, 2 #y row, 2 down
    addi $a1, $t0, 0 #x column, 1 left
    jal  board_get               # v0 = board[rowBelow][board_col]

    bne  $v0, $zero, keyboard_done #if v0 != 0 (meaning occupied), we just skip ahead.
    
    #save our new x, if movement possible
    addi $t0, $t0, 1         # x = x + 1
    sw   $t0, current_col_x
    #todo: redraw after moving:

    j    keyboard_done

s_click:
    
    la $s7, sound_down #play sound first
    jal play_sound 
    
    jal fall_step #run land function.
    # v0 = 0, not landed
    # v0 = 1, landed (and new column spawned)
    j   keyboard_done
    
    #todo: clamping and collision with board.
    #todo: redraw after moving

q_click:
    li $v0, 10      # Quitting Function
	syscall
	
p_click:
    j pause_loop #Calls the Pause Function

keyboard_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
   
clear_play_area:
    #This function just goes through the entire board, and resets everthing to black.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    li $t0, 0
    
clear_row_loop:
    bgt $t0, 14, clear_done_rows #all 14 rows. 
    li $t1, 1 #start at col = 1
    
clear_col_loop:
    bgt $t1, 6, next_row #cols 1-6
    
    move $a0, $t0 #passing in our row
    move $a1, $t1 #pasing in our column
    li $a2, 0x000000   #black color for space
    
    jal draw_cell
    
    addi $t1, $t1, 1 #move up iterative
    
    j clear_col_loop

next_row:
    addi $t0, $t0, 1 #now we move over one row.
    j clear_row_loop

clear_done_rows:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
redraw_frame:

    addi $sp, $sp, -4 
    sw   $ra, 0($sp)

    jal  clear_play_area #first you clear the screen
    jal draw_board #then draw the current board
    jal  draw_current_column #then you draw the new column
    jal draw_next_column #then you draw the next column that could be coming

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
board_get:
    # a0 = row, a1 = col, v0 = board[col][row] = color at the value
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    la   $t8, board #load in address
    li   $t9, 6 #used for multiplying     
    
    mul  $t2, $a0, $t9   # row * 6
    add  $t2, $t2, $a1   # row * 6 + col
    
    sll  $t2, $t2, 2     # 4 bytes
    
    addu $t3, $t8, $t2   # base + offset
    
    lw   $v0, 0($t3)     # getting that color and storing into return variable
    
    lw   $ra, 0($sp) # returning back
    addi $sp, $sp, 4
    jr   $ra

board_set:
    #This function saves the color we want in thar x, y value in the column.
    # a0 = row, a1 = col, $a2 = color we want to save
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    la   $t8, board #Same math as before but we save this time.
    li   $t9, 6          # width = 6,
    
    mul  $t2, $a0, $t9   # row * 6
    add  $t2, $t2, $a1   # row * 6 + col
    
    sll  $t2, $t2, 2     # 4 bytes
    
    addu $t3, $t8, $t2   # base + offset
    
    sw   $a2, 0($t3)     # saving that color in that cell 
    
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

land_current_column:
    # Writes the 3 gems of the current column into board[]
    #Spawns a new random column at the top
    # Rewrite Safety: Uses only $t4–$t7 so it's safe with board_set.
    
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Load current y and x
    lw   $t4, current_col_y      # col (top gem)
    lw   $t5, current_col_x      # row (screen col 1..6)

    # board_col = x - 1 = row - 1
    addi $t5, $t5, -1

    la   $t6, current_col_clr    # pointer to colors
    li   $t7, 0                  # i = 0

land_loop:
    beq  $t7, 3, afterland       # run for each color and then go to afterland.
    # row = y + i
    addu $a0, $t4, $t7           # row = y + i
    move $a1, $t5                # col
    lw   $a2, 0($t6)             # colour
    jal  board_set               # writes to board[row][col]
    addi $t6, $t6, 4             # next colour
    addi $t7, $t7, 1             # i++
    j    land_loop
    
afterland:

reaction_loop:
    #This function is where we check all the matches. And Mark them if needed. 
    # Check Horizontal Matches
    jal  check_matches_hor
    move $s0, $v0               # Save result, 0 = no matches, 1 = matches

    # Check Vertical Matches
    jal  check_matches_vert
    or   $s0, $s0, $v0          # Combine results, $s0 = Horizontal or Vertical
    
    #Check diagonal Right Matches
    jal check_matches_diag_R
    or   $s0, $s0, $v0  # Combine results, $s0 = Horizontal or Vertical or Diag R
    
    #Check diagonal Left matches
    jal check_matches_diag_L # Combine results, $s0 = Horizontal or Vertical or Diag R or Diag L
    or   $s0, $s0, $v0
    
    #if no matches are found, complete the landing, $s0 = 0
    beq  $s0, $zero, land_done

   
    #Matches are found. 
    lw $t2, number_of_matches #load number of matches
    addi $t2, $t2, 1 #add one more and then save that
    sw   $t2, number_of_matches
    
    li $t3, 5 #then check if 5 matches were made. 
    
    blt $t2, $t3, skip_increasing_speed #if there aren't enough matches, just skip increasing the speed
    
    sw   $zero, number_of_matches #reset matches
    
    lw $t2, gravity_speed #essentially we just make the gravity speed faster, if the user has made 5 matches.
    li $t3, 10 #this is our minimum drop speed
    
    ble $t2, $t3, skip_increasing_speed #however if we are at minumum speed just stop increasing speed
    #check if its at max speed (10)
    addi $t2, $t2, -5
    
    sw $t2, gravity_speed #save new gravity speed
    
skip_increasing_speed: #if not enough matches are made, skip the gravity stuff

    la $s7, sound_match #play landing sound. 
    jal play_sound
    
    jal scan_for_bombs #look for bombs
    
    #Delete the gems marked in the matches Board
    jal  clear_marked_gems
    
    # Apply Gravity (Drop unsupported gems)
    jal  apply_gravity
    
    # Visual Update: Redraw the board so the player sees the gems drop
    jal  draw_board
    li   $v0, 32
    li   $a0, 250               # Wait 250ms to show blocks kinda falling
    syscall

    # Chain Reaction: Loop back to see if the drop created **new** matches
    j    reaction_loop


land_done:
    # Spawn a new column at the top middle
    
    jal game_end #check if the game is over, before spawning in a new column
    
    li   $t5, 4 #reset positions
    sw   $t5, current_col_x      

    li   $t4, 0
    sw   $t4, current_col_y      

    jal  init_column   #spawn new column       

    # Restore return address
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
fall_step:
    # Tries to move current column down by 1 row.
    # v0 = 0  = successfully moved down (not landed)
    # v0 = 1  = landed, written into board, new column spawned
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Load current position
    lw   $t4, current_col_y      # y 
    lw   $t5, current_col_x      # x 

    # bottom gem row = y + 2
    addi $t6, $t4, 2             # bottomRow = y + 2

    # row below bottom gem
    addi $t7, $t6, 1             # rowBelow = y + 3

    # Check bottom of board: if rowBelow > 14, then we have to load.
    li   $t6, 14                 # last valid row in board
    bgt  $t7, $t6, do_land_fs    # if rowBelow > 14 , then land

    # Check if there's a gem below in board[rowBelow][board_col]
    # board_col = x - 1
    addi $t6, $t5, -1            # board_col = x - 1

    move $a0, $t7                # rowBelow
    move $a1, $t6                # board_col
    jal  board_get               # v0 = board[rowBelow][board_col]

    bne  $v0, $zero, do_land_fs  # if there is color below then land

    # Safe, then just move down a row. 
    addi $t4, $t4, 1             # y = y + 1
    sw   $t4, current_col_y

    li   $v0, 0                  # not landed, so return $v0 = 0
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

do_land_fs:
    #Will Return $v0 = 1 and spawn in a new column
    # Actually land and spawn new column
    jal  land_current_column

    li   $v0, 1                  # v0 = 1 = landed
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
    
draw_board: 
    #Draw the board/columns that have already been placed. Iterates through board and draws each cell.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $t0, 0  #row (0-14)

row_loop_db:
    bgt  $t0, 14, done_db    # if row > 14 == done
    li   $t1, 0  # col = 0-5 

col_loop_db:
    bgt $t1, 5, next_row_db
 
    #v0 should be your board[row][col]
    move $a0, $t0    # row
    move $a1, $t1    # col
    jal  board_get #first you get the color
    
    beq $v0, $zero, skip_cell_db #if nothing there, then you don't need to draw in that cell
    
    # Convert board col (0-5) to screen col (1-6), this needs to be done since the playing board is one column shifted right.
    move $a0, $t0     # row stays the same
    addi $a1, $t1, 1     # screen col = board col + 1
    move $a2, $v0        # colour

    jal  draw_cell #draw that cell, you know has a color
    
skip_cell_db: #all of this is simple iterative functions.
    addi $t1, $t1, 1
    j col_loop_db

next_row_db:
    addi $t0, $t0, 1
    j row_loop_db
    
done_db:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
check_matches_hor:
    #Checks if any matches horizontally.
    
    # Need to use Save Registers, since other function reset the temp registers.
    addi $sp, $sp, -32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    li   $s5, 0  # 0 = No matches

    # ROW LOOP
    li   $s0, 0             # row = 0
match_row_loop_hor:
    bgt  $s0, 14, match_end_hor #after 14 go to end of horizontal
    
    # COL LOOP
    li   $s1, 0             # col = 0
match_col_loop_hor:
    bgt  $s1, 3, match_next_row_hor # Stop at 3 (checking c, c+1, c+2)

    # 1. GET 3 GEMS, 
    #first color
    move $a0, $s0
    move $a1, $s1
    jal  board_get
    move $s2, $v0           # Color 1

    beq  $s2, 0, match_next_col_hor # Skip Black

    move $a0, $s0
    addi $a1, $s1, 1 # you are checking col + 1
    jal  board_get
    move $s3, $v0           # Color 2

    move $a0, $s0
    addi $a1, $s1, 2 #you are checking col + 2
    jal  board_get
    move $s4, $v0           # Color 3

    # 2. COMPARE
    bne  $s2, $s3, match_next_col_hor #if they aren't matches, go to end
    bne  $s2, $s4, match_next_col_hor #if they aren't matches go to end
    
    # This means you found matches, so save that first
    li   $s5, 1             # Found = 1
    
    # MARK ON Matches BOARD
    
    # Mark Gem 1
    move $a0, $s0
    move $a1, $s1
    jal  mark_match_shadow

    # Mark Gem 2
    move $a0, $s0
    addi $a1, $s1, 1
    jal  mark_match_shadow

    # Mark Gem 3
    move $a0, $s0
    addi $a1, $s1, 2
    jal  mark_match_shadow

match_next_col_hor:
    addi $s1, $s1, 1
    j    match_col_loop_hor
    
match_next_row_hor:
    addi $s0, $s0, 1
    j    match_row_loop_hor

match_end_hor:
    move $v0, $s5           # Return result
    
    # Restore all saved registers
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 32
    jr   $ra
    
    
check_matches_vert:
    #Checks all the vertical matches.
    addi $sp, $sp, -32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    li   $s5, 0             # 0 = No matches

    # ROW LOOP
    li   $s0, 0             # row = 0
match_row_loop_vert:
    # Stop at 12 (checking r, r+1, r+2)
    bgt  $s0, 12, match_end_vert
    
    # COL LOOP
    li   $s1, 0             # col = 0
match_col_loop_vert:
    # columns 0-5
    bgt  $s1, 5, match_next_row_vert 

    # GET 3 GEMS
    
    move $a0, $s0
    move $a1, $s1
    jal  board_get
    move $s2, $v0           # Color 1

    beq  $s2, 0, match_next_col_vert # Skip if Black

    # Row + 1
    addi $a0, $s0, 1
    move $a1, $s1
    jal  board_get
    move $s3, $v0           # Color 2

    # Row + 2
    addi $a0, $s0, 2
    move $a1, $s1
    jal  board_get
    move $s4, $v0           # Color 3

    # compare
    bne  $s2, $s3, match_next_col_vert #if no matches just skip
    bne  $s2, $s4, match_next_col_vert
    
    # This means match found
    li   $s5, 1             # Found = 1
    
    # Mark on shadow board
    
    # Mark Gem 1 (r, c)
    move $a0, $s0
    move $a1, $s1
    jal  mark_match_shadow

    # Mark Gem 2 (r+1, c)
    addi $a0, $s0, 1
    move $a1, $s1
    jal  mark_match_shadow

    # Mark Gem 3 (r+2, c)
    addi $a0, $s0, 2
    move $a1, $s1
    jal  mark_match_shadow

match_next_col_vert:
    addi $s1, $s1, 1
    j    match_col_loop_vert
    
match_next_row_vert:
    addi $s0, $s0, 1
    j    match_row_loop_vert

match_end_vert:
    move $v0, $s5           # Return result
    
    # RESTORE
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 32
    jr   $ra
    
check_matches_diag_R:
    #Checks all the diagonal right matches.
    # Save registers
    addi $sp, $sp, -32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    li   $s5, 0             # 0 = No matches

    #  ROW LOOP
    li   $s0, 0             # row = 0
match_row_loop_diag_R:
    bgt  $s0, 12, match_end_diag_R
    
    # COL LOOP 
    li   $s1, 0             # col = 0
match_col_loop_diag_R:
    bgt  $s1, 3, match_next_row_diag_R # Stop at 3 (checking c, c+1, c+2)

    # GET 3 GEMS
    move $a0, $s0
    move $a1, $s1
    jal  board_get
    move $s2, $v0           # Color 1

    beq  $s2, 0, match_next_col_diag_R # Skip if Black

    addi $a0, $s0, 1     #(r + 1, c + 1)  
    addi $a1, $s1, 1
    jal  board_get
    move $s3, $v0           # Color 2

    addi $a0, $s0, 2 #(r + 2, c + 2)  
    addi $a1, $s1, 2
    jal  board_get
    move $s4, $v0           # Color 3

    # Compare
    bne  $s2, $s3, match_next_col_diag_R #if no matches go to end
    bne  $s2, $s4, match_next_col_diag_R
    
    # Match found
    li   $s5, 1             # Found = 1
    
    # Mark on matches board
    
    # Mark Gem 1
    move $a0, $s0
    move $a1, $s1
    jal  mark_match_shadow

    # Mark Gem 2
    addi $a0, $s0, 1       #(r + 1, c + 1)   
    addi $a1, $s1, 1
    jal  mark_match_shadow

    # Mark Gem 3
    addi $a0, $s0, 2    #(r + 2, c + 2) 
    addi $a1, $s1, 2
    jal  mark_match_shadow

match_next_col_diag_R:
    addi $s1, $s1, 1
    j    match_col_loop_diag_R
    
match_next_row_diag_R:
    addi $s0, $s0, 1
    j    match_row_loop_diag_R

match_end_diag_R:
    move $v0, $s5           # Return result
    
    # Restore
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 32
    jr   $ra
    
    
check_matches_diag_L:
    # Checks all the diagonal left matches.
    addi $sp, $sp, -32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    li   $s5, 0             # 0 = No matches

    # ROW LOOP
    li   $s0, 0             # row = 0
match_row_loop_diag_L:
    bgt  $s0, 12, match_end_diag_L
    
    # COL LOOP
    li   $s1, 2             # col = 0
match_col_loop_diag_L:
    bgt  $s1, 5, match_next_row_diag_L # Stop at 3 (checking c, c+1, c+2)

    # Get 3 gems.
    move $a0, $s0
    move $a1, $s1
    jal  board_get
    move $s2, $v0           # Color 1

    beq  $s2, 0, match_next_col_diag_L # Skip if Black

    addi $a0, $s0, 1     #(r-1, c-1)  
    addi $a1, $s1, -1
    jal  board_get
    move $s3, $v0           # Color 2

    addi $a0, $s0, 2     #(r-1, c-1)  
    addi $a1, $s1, -2
    jal  board_get
    move $s4, $v0           # Color 3

    # 2. COMPARE
    bne  $s2, $s3, match_next_col_diag_L #skip if one of the matches don't work.
    bne  $s2, $s4, match_next_col_diag_L
    
    # Meaning matches found
    li   $s5, 1             # Found = 1
    
    # Mark on matches board
    
    # Mark Gem 1
    move $a0, $s0
    move $a1, $s1
    jal  mark_match_shadow

    # Mark Gem 2
    addi $a0, $s0, 1        #(r+1, c-1)  
    addi $a1, $s1, -1
    jal  mark_match_shadow

    # Mark Gem 3
    addi $a0, $s0, 2    #(r+2, c-1) 
    addi $a1, $s1, -2
    jal  mark_match_shadow

match_next_col_diag_L:
    addi $s1, $s1, 1
    j    match_col_loop_diag_L
    
match_next_row_diag_L:
    addi $s0, $s0, 1
    j    match_row_loop_diag_L

match_end_diag_L:
    move $v0, $s5           # Return result
    
    # RESTORE
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 32
    jr   $ra


mark_match_shadow:
    #This function matches all the gems that have matches on a seperate copy array.
    # Input: a0 = row, a1 = col
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    la   $t8, matches       # Load the matches array address
    li   $t9, 6             # width = 6
    mul  $t2, $a0, $t9      # row * 6 #do the same match as you always do the calculate offset
    add  $t2, $t2, $a1      # + col
    sll  $t2, $t2, 2        # * 4 (bytes)
    addu $t3, $t8, $t2      # address in matches array
    
    li   $t4, 1             # We want to write a 1, at the matches value
    sw   $t4, 0($t3)        # Store 1 at matches[row][col]

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
clear_marked_gems:
    #Iterates through matches array and finds 1. And then makes the gem black, and then puts 0 there in the matches array.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $t0, 0             # row
clear_loop_row:
    bgt  $t0, 14, clear_end
    li   $t1, 0             # col
clear_loop_col:
    bgt  $t1, 5, clear_next_row

    #  Check the matches array at this spot
    la   $t8, matches
    li   $t9, 6
    mul  $t2, $t0, $t9
    add  $t2, $t2, $t1
    sll  $t2, $t2, 2
    addu $t3, $t8, $t2      # Address in matches array
    
    lw   $t4, 0($t3)        # Get the value at that point
    
    beq  $t4, 0, clear_skip # If 0, skip

    # It's a match! 
    # Delete from Board
    move $a0, $t0
    move $a1, $t1
    li   $a2, 0             # Black
    jal  board_set
    
    # Now we recalculate: to get to that same point to delete in matches.
    la   $t8, matches
    li   $t9, 6
    mul  $t2, $t0, $t9
    add  $t2, $t2, $t1
    sll  $t2, $t2, 2
    addu $t3, $t8, $t2 
    
    li   $t4, 0
    sw   $t4, 0($t3)        # matches[r][c] = 0

clear_skip:
    addi $t1, $t1, 1
    j    clear_loop_col

clear_next_row:
    addi $t0, $t0, 1
    j    clear_loop_row

clear_end:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
apply_gravity:
    #This function will apply the gravity, after all the deleting
    #It uses two variables and checks each columns, and 1 stays at the valid gem, and the other keeps iterating up that column, until it finds a valid gem
    #which then it brings down to where the other iterative is waiting.
    # Initalize save registers
    addi $sp, $sp, -20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)    # col
    sw   $s1, 8($sp)    # write_row
    sw   $s2, 12($sp)   # read_row
    sw   $s3, 16($sp)   # temp color

    li   $s0, 0         # col = 0
gravity_col_loop:
    bgt  $s0, 5, gravity_end #if all columns are don

    # Initialize iterative, starting at the bottom row.
    li   $s1, 14        # write_row starts at bottom
    li   $s2, 14        # read_row starts at bottom

gravity_read_loop:
    blt  $s2, 0, gravity_fill_loop  # If read_row < 0, we are done reading

    # Get color at (read_row, col)
    move $a0, $s2
    move $a1, $s0
    jal  board_get
    move $s3, $v0       # s3 = color

    # If color is Black, just decrease read_row, meaning go up
    beq  $s3, 0, gravity_decrease_read

    # If color is valid, move it to (write_row, col)
    move $a0, $s1       # write_row
    move $a1, $s0       # col
    move $a2, $s3       # color
    jal  board_set

    # Move write_row up
    addi $s1, $s1, -1

gravity_decrease_read:
    addi $s2, $s2, -1   # read_row -1
    j    gravity_read_loop

gravity_fill_loop:
    # Now fill the remaining top rows with Black
    blt  $s1, 0, gravity_next_col   # If write_row < 0, column is fulldone

    move $a0, $s1
    move $a1, $s0
    li   $a2, 0         # Black
    jal  board_set #Save black into that value.

    addi $s1, $s1, -1   # write_row -1
    j    gravity_fill_loop

gravity_next_col:
    addi $s0, $s0, 1
    j    gravity_col_loop

gravity_end:
    #Restore all the saved registers.
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)     
    lw   $s1, 8($sp)     
    lw   $s2, 12($sp)    
    lw   $s3, 16($sp)   
    addi $sp, $sp, 20
    jr   $ra
    
game_end:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    li $t0, 0 #column initialize
    
game_end_loop:
    #This loop checks if the game_end condition is matched. This is done by checking the top row and checking if any gems have color. if so it jumps to
    #game end screen
    
    bgt $t0, 5, game_end_done
    
    li $a0, 0 #row = 0
    move $a1, $t0 #col we iterate through
    
    jal board_get #returns color in v0
    
    bne $v0, $zero, game_end_screen #if color is not black, game over
    
    addi $t0, $t0, 1
    
    j game_end_loop
    
game_end_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
game_end_screen:
    
    jal clear_play_area #first it'll clean the screen
        
    jal draw_game_over_text #then it prints the game_over_screen
    la $s7, sound_gameover #then plays game_over sound
    jal play_sound

game_end_wait_input:
    #this loop sits here waiting to see if user will pick any options in the game_over screen
    #Q is quit game
    #R is restart game.
    
    li $v0, 32 #we sleep it, so loop doesn't run too fast.
    li $a0, 100
    syscall
    
    #Copied code from keyboard_input
    lw $t7, ADDR_KBRD               # $t7 = base address for keyboard
    lw $t8, 0($t7)                  # Load first word from keyboard
    beq $t8, 0, game_end_wait_input # if no key is clicked don't do anything 
    
    lw   $t8, 4($t7) # **which** key is clicked.
    
    li  $t9, 'q' #user wants to quit
    beq $t8, $t9, q_click #jump to original quit 
    
    li  $t9, 'r' #user wants to restart
    beq $t8, $t9, reset_restart #jump to restart func.
    
    j game_end_wait_input #keep re-looping
    
reset_restart: #just reset all the board and matches so game basically restarts
    # First we wipe the screen
    # Total size calculation:
    # 256x256 display / 8x8 units = 32x32 grid
    # 32 * 32 = 1024 units total
    # 1024 units * 4 bytes/unit = 4096 bytes
    #Essentially it loops through the entire bitmap and makes it 0 = black. It also loops through the matches array and erases that aswell.
    
    lw $t0, ADDR_DSPL 
    li $t1, 4096
    add $t2, $t0, $t1
    
wipe_screen_loop:
    bge $t0, $t2, wipe_data
    
    #Save the color black there. 
    sw $zero, 0($t0)
    
    addi $t0, $t0, 4 #move to next word.
    
    j wipe_screen_loop

wipe_data:
    
    la $t0, board 
    la $t1, matches
    
    li $t2, 0 #start
    li $t3, 360 #end
    
wipe_loop:
    beq, $t2, $t3, main
    
    # Clear board + offset
    add $t4, $t0, $t2
    sw  $zero, 0($t4)
    
    # Clear matches + offset
    add $t4, $t1, $t2
    sw  $zero, 0($t4)
    
    addi $t2, $t2, 4
    j    wipe_loop

wipe_done:
    # Reset start position to default
    li   $t0, 4
    sw   $t0, current_col_x
    li   $t0, 2
    sw   $t0, current_col_y
    j    main #Restart the game.

draw_game_over_text:
    #This function draws the game over screen
    #It manually calls each draw_cell until GME OVR Shows up on the screen
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $a2, 0xFFFFFF      # Set Color white

    # LETTER G (Start X = 4)
    # Row 0: XXX
    li $a0, 10
    li $a1, 4       
    jal draw_cell
    li $a1, 5
    jal draw_cell
    li $a1, 6
    jal draw_cell
    
    # Row 1: X
    li $a0, 11
    li $a1, 4
    jal draw_cell
    
    # Row 2: X.X
    li $a0, 12
    li $a1, 4
    jal draw_cell
    li $a1, 6
    jal draw_cell
    
    # Row 3: X.X
    li $a0, 13
    li $a1, 4
    jal draw_cell
    li $a1, 6
    jal draw_cell
    
    # Row 4: XXX
    li $a0, 14
    li $a1, 4
    jal draw_cell
    li $a1, 5
    jal draw_cell
    li $a1, 6
    jal draw_cell

    # LETTER M (Start X = 8)
    # Row 0: X.X
    li $a0, 10
    li $a1, 8
    jal draw_cell
    li $a1, 10
    jal draw_cell
    
    # Row 1: XXX
    li $a0, 11
    li $a1, 8
    jal draw_cell
    li $a1, 9
    jal draw_cell
    li $a1, 10
    jal draw_cell
    
    # Row 2: X.X
    li $a0, 12
    li $a1, 8
    jal draw_cell
    li $a1, 10
    jal draw_cell
    
    # Row 3: X.X
    li $a0, 13
    li $a1, 8
    jal draw_cell
    li $a1, 10
    jal draw_cell
    
    # Row 4: X.X
    li $a0, 14
    li $a1, 8
    jal draw_cell
    li $a1, 10
    jal draw_cell

    # LETTER O (Start X = 14)
    # Row 0: XXX
    li $a0, 10
    li $a1, 14
    jal draw_cell
    li $a1, 15
    jal draw_cell
    li $a1, 16
    jal draw_cell
    
    # Row 1: X.X
    li $a0, 11
    li $a1, 14
    jal draw_cell
    li $a1, 16
    jal draw_cell
    
    # Row 2: X.X
    li $a0, 12
    li $a1, 14
    jal draw_cell
    li $a1, 16
    jal draw_cell
    
    # Row 3: X.X
    li $a0, 13
    li $a1, 14
    jal draw_cell
    li $a1, 16
    jal draw_cell
    
    # Row 4: XXX
    li $a0, 14
    li $a1, 14
    jal draw_cell
    li $a1, 15
    jal draw_cell
    li $a1, 16
    jal draw_cell

    # LETTER V (Start X = 18)
    # Row 0: X.X
    li $a0, 10
    li $a1, 18
    jal draw_cell
    li $a1, 20
    jal draw_cell
    
    # Row 1: X.X
    li $a0, 11
    li $a1, 18
    jal draw_cell
    li $a1, 20
    jal draw_cell
    
    # Row 2: X.X
    li $a0, 12
    li $a1, 18
    jal draw_cell
    li $a1, 20
    jal draw_cell
    
    # Row 3: .X.
    li $a0, 13
    li $a1, 19
    jal draw_cell
    
    # Row 4: .X.
    li $a0, 14
    li $a1, 19
    jal draw_cell

    # LETTER R (Start X = 22)
    # Row 0: XX.
    li $a0, 10
    li $a1, 22
    jal draw_cell
    li $a1, 23
    jal draw_cell
    
    # Row 1: X.X
    li $a0, 11
    li $a1, 22
    jal draw_cell
    li $a1, 24
    jal draw_cell
    
    # Row 2: XX.
    li $a0, 12
    li $a1, 22
    jal draw_cell
    li $a1, 23
    jal draw_cell
    
    # Row 3: X.X
    li $a0, 13
    li $a1, 22
    jal draw_cell
    li $a1, 24
    jal draw_cell
    
    # Row 4: X.X
    li $a0, 14
    li $a1, 22
    jal draw_cell
    li $a1, 24
    jal draw_cell

    # done, drawing
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

pause_loop:
    #This is what happens when the user clicks P. It's our pause loop.
    
    jal draw_pause_icon
    
pause_wait_loop:
    
    li $v0, 32 #Don't run loop too fast
    li $a0, 100
    syscall
    
    #Same code copypasted from keyboard_input
    lw $t7, ADDR_KBRD               # $t7 = base address for keyboard
    lw $t8, 0($t7)                  # Load first word from keyboard
    beq $t8, 0, pause_wait_loop # if no key is clicked don't do anything 
    
    lw   $t8, 4($t7) # **which** key is clicked.
    
    li  $t9, 'p'
    beq $t8, $t9, draw_pause_p_click #check if user is trying to unpause or not. 
    
    j pause_wait_loop
    

draw_pause_icon:
    #Drawing the pause icon on the screen in white
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    li   $a2, 0xFFFFFF      # White Color
    jal  draw_pause_pixels #call the func.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

clear_pause_icon: 
    #Drawinfg the pause icon but in black so it looks erased.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    li   $a2, 0x000000      # Black Color
    jal  draw_pause_pixels #call the func.
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

draw_pause_pixels:
    
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    li   $t0, 10            # Start at this row
    li   $t1, 17            # End at this row 
    
pause_loop_y: #Run this loop until we reach the column where we are done drawing.
    beq $t0, $t1, pause_draw_done
    
    move $a0, $t0 #y draw
    li $a1, 12 ##the column we draw first line col = 12
    
    jal draw_cell #draw the cell
    
    move $a0, $t0 #y draw
    li $a1, 15 #second col we draw col = 15
    
    jal draw_cell
    
    addi $t0, $t0, 1 #increase iterative
    
    j pause_loop_y

pause_draw_done:    
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
draw_pause_p_click:
    #if user unpauses. delete the pause icon and jump back to game_loop
    jal clear_pause_icon
    
    j game_loop
    
play_sound:
    #This function plays all the sounds we have saved. Implementation was learned from online source.
    addi $sp, $sp, -8       # Setup stack pointer
    sw   $ra, 0($sp)        # Save return address
    sw   $v0, 4($sp)     
    # Save v0 since syscall trashes it)

    # Load arguments from the address in $s7
    lw   $a0, 0($s7)        # Pitch
    lw   $a1, 4($s7)        # Duration
    lw   $a2, 8($s7)         # Instrument
    lw  $a3, 12($s7)        # Volume

    li   $v0, 31            # Syscall 31: MIDI Out plays sound
    syscall

    lw   $v0, 4($sp)        # Restore v0
    lw   $ra, 0($sp)        # Restore ra
    addi $sp, $sp, 8
    jr   $ra
    
draw_next_column:
    #This function draws the next column.
    #It just reads through next_col_clr array and draw's those cells at a certain x,y
    addi $sp, $sp, -8  
    sw $s0, 4($sp) #save $s0 if it's being used elsewhere
    sw $ra, 0($sp) 
    
    la $s0, next_col_clr #load in the array
    
    li $a0, 5
    li $a1, 10
    lw $a2, 0($s0) #draw first gem 
    jal draw_cell
       
    li $a0, 6
    li $a1, 10
    lw $a2, 4($s0) #draw second gem 
    jal draw_cell
    
    li $a0, 7
    li $a1, 10
    lw $a2, 8($s0) #draw third gem 
    jal draw_cell
    
    lw $s0, 4($sp) #restore the value of $s0
    lw   $ra, 0($sp)    # Restore ra
    addi $sp, $sp, 8
    jr   $ra
    
    
scan_for_bombs:
    # Scan_for_bombs which are white cells.
    # Iterates through the board. If a matched gem is white, marks the whole column.
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $s0, 0             # Row iterator
scan_bomb_row:
    bgt  $s0, 14, scan_bomb_done
    li   $s1, 0             # Col iterator

scan_bomb_col:
    bgt  $s1, 5, scan_bomb_next_row

    # Check if this cell is matched (matches[r][c] == 1)
    # Calculate the address manually to avoid clobbering registers with function call
    la   $t8, matches
    li   $t9, 6
    mul  $t2, $s0, $t9      # row * 6
    add  $t2, $t2, $s1      # + col
    sll  $t2, $t2, 2        # * 4
    addu $t3, $t8, $t2
    lw   $t4, 0($t3)        # Load match value at that.
    
    beq  $t4, $zero, scan_bomb_next_col  # If 0 (no match), skip

    # If it is matched. Check the color on the actual board. We need to see if its white.
    move $a0, $s0
    move $a1, $s1
    jal  board_get
    move $t5, $v0           # t5 = Color

    # Check is it White? (Column Bomb)
    li   $t6, 0xFFFFFF
    bne  $t5, $t6, scan_bomb_next_col #if not white, go to the next column

    # Detonate
    # Mark entire column $s1 as matched in the shadow board
    move $a1, $s1           # Col is fixed
    li   $a0, 0             # Start at row 0
    
col_bomb_loop:
    #Iterates through the column, and marks everything.
    bgt  $a0, 14, scan_bomb_next_col 
    jal  mark_match_shadow
    addi $a0, $a0, 1
    j    col_bomb_loop

scan_bomb_next_col:
    addi $s1, $s1, 1
    j    scan_bomb_col

scan_bomb_next_row:
    addi $s0, $s0, 1
    j    scan_bomb_row

scan_bomb_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
    
    

    
    
    
    
    
    
    
    
    
    

    
    
    
    


