" TAPE VIEW


let s:interface_name = "__ticker_controller__"
let s:interface_handle = -1

let s:api = {}

let s:base_statusline = ""

" ---------------------------- AUTOCOMMANDS --------------------------------

augroup Ticker#TapeView
    autocmd!
    autocmd User Ticker#TapeControllerReady :call CreateTapeView() 
augroup END


" ---------------------------- INTERFACE ----------------------------------

function CreateTapeView()
    let s:interface_handle = bufnr(s:interface_name)
    let s:api = getbufvar(s:interface_handle, "api")
    
    let s:api.TapeView = {
                \"UpdateTapeView": funcref("<SID>UpdateTapeView"),
                \"ResetTapeView": funcref("<SID>ResetTapeView")
                \}
    if s:base_statusline == ""
        :call s:SetBaseStatusLine()
    endif

endfunction

function s:UpdateTapeView()
    let &statusline = s:base_statusline . "%=" . s:ticker_tape
endfunction

function s:ResetTapeView()
    let &statusline = s:base_statusline
endfunction


" ------------------------- HELPERS -------------------------------
function s:SetBaseStatusLine() 
    let s:base_statusline = &statusline
endfunction


