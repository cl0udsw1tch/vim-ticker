
" TOP-LEVEL CONTROLLER

let s:max_tickers = 10

let s:model_name="__ticker_model__"
let s:model_handle=-1
let s:interface_name="__ticker_interface__"
let s:interface_handle = -1

let s:model = {}
let s:api = {}


" ---------------------- MODEL LIFECYCLE -------------------------

function CreateModel()
    :doautocmd User Ticker#CreateModel
    let s:model_handle = bufnr(s:model_name)
    let s:model = getbufvar(s:model_handle, "model")
endfunction

function DestroyModel()
    :doautocmd User Ticker#DestroyModel
    let s:model_handle = -1
    let s:model = {}
endfunction

function ClearModel()
    :call s:model.ClearModel()
endfunction


" --------------------- CONTROLLER LIFECYCLE ---------------------

function CreateInterface()
    let s:interface_handle = bufadd(s:interface_name)
    :call setbufvar(s:interface_handle, "&buflisted", 0)
    :call setbufvar(s:interface_handle, "&buftype", "nofile")
    :call setbufvar(s:interface_handle, "&readonly", 1)
    :call setbufvar(s:interface_handle, "&modifiable", 0)
    :call bufload(s:interface_handle)
    :call setbufvar(s:interface_handle, "api", s:api)
    :doautocmd User Ticker#ControllerReady 
endfunction

function DestroyInterface()
    if s:interface_handle != -1
        execute "bwipeout" s:interface_handle  
        let s:interface_handle = -1
        let s:api = {}
    endif   
endfunction


" ----------------------- INTERFACE --------------------------

function s:CreateTape()
    :call s.api.TapeController.CreateTape() 
endfunction

function s:DestroyTape()
    :call s.api.TapeController.DestroyTape()
endfunction

function s:CreateChart()
    :call s.api.ChartController.CreateChart()
endfunction

function s:DestroyChart()
    :call s.api.ChartController.DestroyChart()
endfunction

function s:CreateTicker(...)
    if a:0 > s:max_tickers
        echo "Too many tickers, maximum " . string(s:max_tickers) . " allowed"
        return
    endif 
    if s:interface_handle == -1:
        :call s:CreateInterface()
    endif
    :call s:CreateModel()
    :call s:model.StartModel(a:000)
endfunction

function s:StopTicker()
    :call s:DestroyTape()
    :call s:DestroyChart()
    :call s:ClearModel()
endfunction

function s:DestroyTicker()
    :call s:StopTicker()
    :call s:DestroyModel()
    :call s:DestroyInterface()
endfunction


" ================== COMMANDS/ENTRYPOINTS ======================

command -nargs=* Ticker :call call(function("<SID>CreateTicker"), split(<q-args>, " "))
command NoTicker :call s:DestroyTicker()
command TickerTape :call s:CreateTape()
command NoTickerTape :call s:DestroyTape()
command TickerChart :call s:CreateChart()
command NoTickerChart :call s:DestroyChart()


















