" TAPE CONTROLLER


highlight! HL_SYM ctermfg=White ctermbg=Black cterm=bold guifg=#FFFFFF guibg=#000000 gui=bold
highlight! HL_POS ctermfg=Green ctermbg=Black cterm=bold guifg=#00FF00 guibg=#000000 gui=bold
highlight! HL_NEG ctermfg=Red ctermbg=Black cterm=bold guifg=#FF0000 guibg=#000000 gui=bold

let s:HL_SYM = "%#HL_SYM#"
let s:HL_POS = "%#HL_POS#"
let s:HL_NEG = "%#HL_NEG#"
let s:HL_NTL = s:HL_SYM
let s:HL_Map = {-1: s:HL_NEG, 0: s:HL_NTL, 1: s:HL_POS}
let s:change_sym_map =  {-1: "\u25BC", 0: "\u25B2" , 1: "\u25B2"}

let s:ticker_rotate_handle = -1
let s:ticker_head_offset = 0
let s:ticker_head = 0
let s:tape_len = 50
let s:rotate_hz = 5

let s:interface_name = "__ticker_interface__"
let s:interface_handle = -1
let s:model_name = "__ticker_model__"
let s:model_handle = -1

let s:api = {}
let s:model = {}


" ------------------------- AUTOCOMMANDS ------------------------------

augroup Ticker#TapeController
autocmd!
autocmd User Ticker#ControllerReady :call CreateTapeController()
augroup END

"--------------------------- INTERFACE --------------------------------

function s:CreateTapeController()
    let s:interface_handle = bufnr(s:interface_name)
    let s:api = getbufvar(s:interface_handle, "api")
    let s:api.TapeController = {
        \"CreateTape":  funcref("<SID>CreateTape"),
        \"DestroyTape": funcref("<SID>DestroyTape")
        \}
    let s:model_handle = bufnr(s:model_name)
    let s:model = getbufvar(s:model_handle, "model")
    :doautocmd User Ticker#TapeControllerReady
endfunction

function s:CreateTape()
    let s:rotate_handle = timer_start(1000/s:rotate_hz, function("<SID>RotateTape"), {'repeat':-1})
endfunction

function s:DestroyTape()
    if s:rotate_handle != -1
        :call timer_stop(s:rotate_handle)
        let s:rotate_handle = -1
        let s:ticker_head_offset=0
        let s:ticker_head=0
    endif
    :call s.api.TapeView.ResetTape()
endfunction

" -------------------------- PROCEDURES ---------------------------- " 

function s:RotateTape()
    let s:ticker_tape = ""
    let ticker_idx = s:ticker_head
    let j0 = s:ticker_head_offset
    let j = s:ticker_head_offset
    let char_count = 0
    let ticker = s:model.tickers[ticker_idx]
    let name_token = ticker . " "

    let close = s:model.price_data[ticker0].prev_close
    let price = s:model.GetLastPrice(ticker0)
    let delta = (price - close) / close
    let change = delta > 0 ? 1 : delta < 0 ? -1 : 0
    
    let price_token = s:FormatPrice(price) . " "
    let delta_token = "(" . s:change_sym_map[change0] .  s:FormatDelta(delta) . ") "
    let m_name0 = strchars(name_token)
    let m_price0 = strchars(price_token)
    let m_delta0 = strchars(delta_token)
    let hl_tag0 = s:HL_Map[change0]
    if j<m_name0
        let s:ticker_tape .= s:HL_Map[0]
    elseif j>=m_name0
        let s:ticker_tape .= hl_tag0
    endif
    if j0==0
        let j+=1
    elseif j0==m_name0
        let j+=1
    endif
    while char_count<s:tape_len
        let ticker = s:tickers[ticker_idx]
        
        let close = s:model.price_data[ticker].prev_close
        let price = s:model.GetLastPrice(ticker)
        let delta = close != 0 ? (price - close) / close : 0
        let change = delta > 0 ? 1 : delta < 0 ? -1 : 0
    
        let name_token = ticker . " "
        let price_token = s:FormatPrice(price) . " "   
        let delta_token = "(" . s:change_sym_map[change] . s:FormatDelta(delta) . ") "

        let m_name = strchars(name_token)
        let m_price = strchars(price_token)
        let m_delta = strchars(delta_token)
        let hl_tag = s:HL_Map[change]

        if j==0
            let s:ticker_tape .= s:HL_Map[0] . name_token[0]
        elseif j<m_name
            let s:ticker_tape .= name_token[j]
        elseif j==m_name
            let s:ticker_tape .= hl_tag . price_token[0]
        elseif j>m_name
            let s:ticker_tape .= strcharpart(price_token . delta_token, j-m_name, 1)
        endif
        let char_count += 1
        let j = (j+1)%(m_name+m_price+m_delta)
        if j==0
            let ticker_idx = (ticker_idx+1)%s:model.n_tickers
        endif
    endwhile
    let s:ticker_head_offset=(j0+1)%(m_name0+m_price0+m_delta0)
    if s:ticker_head_offset==0
        let s:ticker_head=(s:ticker_head+1)%s:model.n_tickers
    endif
    :call s:api.TapeView.UpdateTape(s:ticker_head)
endfunction


" ------------------------- HELPERS ---------------------------------

function s:FormatPrice(raw_float)
    if a:raw_float == -1:
        return "-1"
    endif
    let formatted_price = printf("%.2f", a:raw_float) 
    return formatted_price
endfunction

function s:FormatDelta(raw_float)
    if a:raw_float == 0:
        return "0"
    endif
    let fdelta = printf("%.2f", abs(a:raw_float)*100) . "\uFE6A"
    return fdelta
endfunction





