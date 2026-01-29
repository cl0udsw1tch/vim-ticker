
" CHART CONTROLLER

let s:ticker_idx = 0
let s:chart_hz = 1/2
let s:chart_handle = -1

let s:model_name = "__ticker_model__"
let s:model_handle = -1
let s:interface_name = "__ticker_controller__"
let s:interface_handle = -1

let s:model = {}
let s:model_interface = {}
let s:api = {}


" ------------------------ AUTOCOMMANDS ---------------------------

augroup Ticker#ChartController
autocmd!
autocmd User Ticker#ControllerReady :call s:CreateChartController()
augroup END


" ------------------------ INTERFACE ------------------------------ 

function s:CreateChartController()
    "echo "Creating chart controller ...."
    let s:interface_handle = bufnr(s:interface_name)
    let s:api = getbufvar(s:interface_handle, "api")
    let s:model_handle = bufnr(s:model_name)
    let s:model = getbufvar(s:model_handle, "model")
    let s:model_interface = getbufvar(s:model_handle, "model_interface")
    let s:api.ChartController = {
        \"CreateChart":  funcref("<SID>CreateChart"),
        \"DestroyChart": funcref("<SID>DestroyChart"),
        \"ShowChart": funcref("<SID>ShowChart"),
        \"HideChart": funcref("<SID>HideChart"),
        \"BarIterIsValid": s:model_interface["StreamIterIsValid"],
        \"BarIterPrev": s:model_interface["StreamIterPrev"],
        \"BarIterReset": s:model_interface["StreamIterReset"],
        \"GetBarVal": s:model_interface["GetStreamItemVal"],
        \"ChartTickers": s:model.tickers,
        \}
    :doautocmd User Ticker#ChartControllerReady
endfunction

function s:CreateChart()
    :call s:ShowChart()
    let s:chart_handle = timer_start(1000/s:chart_hz, funcref("<SID>UpdateChart"), {'repeat': -1})
endfunction

function s:ShowChart()
    :call s:api.ChartView.ShowChart()
endfunction

function s:HideChart()
    :call s:api.ChartView.HideChart()
endfunction

function s:NextChart()
    let s:ticker_idx = (s:ticker_idx + 1) % s:model.n_tickers
    :call s:api.ChartView.ChangeChart(s:model.tickers[s:ticker_idx])
endfunction

function s:PrevChart()
     let s:ticker_idx = (s:ticker_idx - 1) % s:model.n_tickers
    :call s:api.ChartView.ChangeChart(s:model.tickers[s:ticker_idx])
endfunction

function s:DestroyChart()
    if s:chart_handle != -1
        :call timer_stop(s:chart_handle)
        let s:chart_handle = -1
    endif
    :call s:api.ChartView.DestroyChartView()
endfunction

function s:UpdateChart(timerId)
    "echo "CONTROLLER UDPATING CHART"
    let ticker = s:model.tickers[s:ticker_idx]
    let buf_iter = s:model_interface["StreamIterator"](s:model.price_data[ticker].prices)
    "echo "buf iter"
    "echo buf_iter
    "echo "price_data"
    "echo s:model.price_data[ticker]
    let last = s:model.price_data[ticker].last 
    :call s:api.ChartView.UpdateChartView(ticker, buf_iter, last) 
endfunction






















