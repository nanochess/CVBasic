;;; CV BASIC Epilogue

; data in low RAM
    aorg >2000

; must be even aligned
; mirror for sprite table
sprites	    bss 128

; Vars can start at >2080
    aorg >2080

