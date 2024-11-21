 ' Test

    CLS

    DEFINE SPRITE 16, 3, bitmaps

 

    ' Sprite 0    
    x = 120
    y = 175

 

    ' Sprite 1
    x1 = 120
    y1 = 90    

 

    ' Sprite 2
    x2 = 120
    y2 = 40
    
main_loop:
    
    SPRITE 0, y - 1, x, 16 * 4, 10
    SPRITE 1, y1 - 1, x1, 17 * 4, 8
    SPRITE 2, y2 - 1, x2, 18 * 4, 8

 

    WAIT 
    
    GOTO main_loop

 

bitmaps:
    BITMAP "................"
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP "......XXXX......"
    BITMAP "X....XX..XX....X"
    BITMAP "X...XXX..XXX...X"
    BITMAP "X..XXX....XXX..X"
    BITMAP "XXXXXX....XXXXXX"
    BITMAP "XXXXXXX..XXXXXXX"
    BITMAP "..XXXXXXXXXXXX.."
    BITMAP "..XX.XXXXXX.XX.."
    BITMAP "...XX......XX..."
    BITMAP "....XXXXXXXX...."
    BITMAP "......XXXX......"

 

    BITMAP "................"
    BITMAP "................"
    BITMAP "................"
    BITMAP "................"
    BITMAP "......XXXX......"
    BITMAP ".....X....X....."
    BITMAP "....X.X..X.X...."
    BITMAP "...X........X..."
    BITMAP "...X..X..X..X..."
    BITMAP "....X..XX..X...."
    BITMAP ".....X....X....."
    BITMAP "......XXXX......"
    BITMAP "................"
    BITMAP "................"
    BITMAP "................"
    BITMAP "................"

 

    BITMAP "......XXXX......"
    BITMAP "....XXXXXXXX...."
    BITMAP "...XX......XX..."
    BITMAP "..XX.XXXXXX.XX.."
    BITMAP "..XXXXXXXXXXXX.."
    BITMAP "XXXXXXX..XXXXXXX"
    BITMAP "XXXXXX....XXXXXX"
    BITMAP "X..XXX....XXX..X"
    BITMAP "X...XXX..XXX...X"
    BITMAP "X....XX..XX....X"
    BITMAP "......XXXX......"
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP ".......XX......."
    BITMAP "................"
