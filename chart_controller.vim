
" CHART CONTROLLER

highlight! GREEN_BAR cterm=bold ctermbg=Black ctermfg=Green guibg=#000000 guifg=#00FF00
highlight! RED_BAR cterm=bold ctermbg=Black ctermfg=Red guibg=#000000 guifg=#FF0000

let s:row_match_ids = []
let s:chart_lines = 50
let s:chart_cols = 50
let s:chart_hz = 1/2
let s:chart_handle = -1

let s:model_name = "__ticker_model__"
let s:model_handle = -1
let s:interface_name = "__ticker_controller__"
let s:interface_handle = -1

let s:model = {}
let s:api = {}


" ------------------------ AUTOCOMMANDS ---------------------------

augroup Ticker#ChartController
autocmd!
autocmd User Ticker#ControllerReady :call s:CreateChartController()
augroup END


" ------------------------ INTERFACE ------------------------------ 

function s:CreateChartController()
    echo "Creating chart controller ...."
    let s:interface_handle = bufnr(s:interface_name)
    let s:api = getbufvar(s:interface_handle, "api")
    let s:api.ChartController = {
        \"CreateChart":  funcref("<SID>CreateChart"),
        \"DestroyChart": funcref("<SID>DestroyChart")
        \}

    let s:model_handle = bufnr(s:model_name)
    let s:model = getbufvar(s:model_handle, "model")
    :doautocmd User Ticker#ChartControllerReady
endfunction

function s:CreateChart()
    let s:chart_handle = timer_start(1000/s:chart_hz, funcref("<SID>UpdateChart"))
endfunction

function s:DestroyChart()
    if s:chart_handle != -1
        :call timer_stop(s:chart_handle)
        let s:chart_handle = -1
    endif
    :call s:api.ChartView.DestroyChartView()
endfunction

function s:UpdateChart()


endfunction
















