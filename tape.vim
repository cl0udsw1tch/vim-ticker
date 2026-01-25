highlight! HL_SYM ctermfg=White ctermbg=Black cterm=bold guifg=#FFFFFF guibg=#000000 gui=bold
highlight! HL_POS ctermfg=Green ctermbg=Black cterm=bold guifg=#00FF00 guibg=#000000 gui=bold
highlight! HL_NEG ctermfg=Red ctermbg=Black cterm=bold guifg=#FF0000 guibg=#000000 gui=bold

let s:HL_SYM = "%#HL_SYM#"
let s:HL_POS = "%#HL_POS#"
let s:HL_NEG = "%#HL_NEG#"
let s:HL_NTL = s:HL_SYM
let s:HL_Map = {-1: s:HL_NEG, 0: s:HL_NTL, 1: s:HL_POS}
"let s:change_sym_map = {-1: '-', 0: '+' , 1: '+'}
let s:change_sym_map =  {-1: "\u25BC", 0: "\u25B2" , 1: "\u25B2"}

let s:buf_name = "__ticker_model__"
let s:buf_handle = -1






