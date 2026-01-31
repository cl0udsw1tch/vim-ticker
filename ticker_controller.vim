
" TOP-LEVEL CONTROLLER

:set laststatus=2

let s:max_tickers = 10
let s:tape = 0
let s:chart = 0
let s:model_name="__ticker_model__"
let s:model_handle=-1
let s:interface_name="__ticker_controller__"
let s:interface_handle = -1

let s:model = {}
let s:model_interface = {}
let s:api = {}

function g:FloatMax(arr)
	let r = -pow(2,32)
	for e in a:arr
		if e>r
			let r=e
		endif
	endfor
	return r
endfunction

function g:FloatMin(arr)
	let r = pow(2,32)
	for e in a:arr
		if e<r
			let r=e
		endif
	endfor
	return r
endfunction

function g:IndexOf(arr, val)
	let i = 0
	for it in a:arr
		if it==a:val
			return i
		endif
		let i+=1
	endfor
	return -1
endfunction
" ---------------------- MODEL LIFECYCLE -------------------------

function s:CreateModel()
    :doautocmd User Ticker#CreateModel
    let s:model_handle = bufnr(s:model_name)
    let s:model = getbufvar(s:model_handle, "model")
    let s:model_interface = getbufvar(s:model_handle, "model_interface")
    "echo "Model " . s:model_handle
endfunction

function s:StartModel(tickers)
    :call s:model_interface["StartModel"](a:tickers)
    "echo "Model started"
endfunction

function s:DestroyModel()
    :doautocmd User Ticker#DestroyModel
    let s:model_handle = -1
    let s:model = {}
endfunction

function s:ClearModel()
    :call s:model_interface["ClearModel"]()
endfunction


" --------------------- CONTROLLER LIFECYCLE ---------------------

function s:CreateInterface()
    "echo "Creating controller interface"
    let s:interface_handle = bufadd(s:interface_name)
    :call setbufvar(s:interface_handle, "&buflisted", 0)
    :call setbufvar(s:interface_handle, "&buftype", "nofile")
    :call setbufvar(s:interface_handle, "&readonly", 1)
    :call setbufvar(s:interface_handle, "&modifiable", 0)
    :call bufload(s:interface_handle)
    :call setbufvar(s:interface_handle, "api", s:api)
    :doautocmd User Ticker#ControllerReady 
endfunction

function s:DestroyInterface()
    if s:interface_handle != -1
        execute "bwipeout" s:interface_handle  
        let s:interface_handle = -1
        let s:api = {}
    endif   
endfunction


" ----------------------- INTERFACE --------------------------

function s:CreateTape()
    :call s:api.TapeController.CreateTape() 
    let s:tape=1
endfunction

function s:DestroyTape()
    :call s:api.TapeController.DestroyTape()
    let s:tape=0
endfunction

function s:CreateChart()
    if s:chart
        :call s:api.ChartController.ShowChart()
    else
        let s:chart = 1
        :call s:api.ChartController.CreateChart()
    endif
endfunction

function s:DestroyChart()
    :call s:api.ChartController.DestroyChart()
    let s:chart = 0
endfunction

function s:HideChart()
    :call s:api.ChartController.HideChart()
endfunction

function s:NextChart()
    :call s:api.ChartController.NextChart()
endfunction

function s:PrevChart()
    :call s:api.ChartController.PrevChart()
endfunction

function s:CreateTicker(...)
    "echo "Tickers "
    "echo  a:000
    if a:0 > s:max_tickers
        "echo "Too many tickers, maximum " . string(s:max_tickers) . " allowed"
        return
    endif 
    :call s:CreateModel()
    if s:interface_handle == -1
        :call s:CreateInterface()
    endif
    :call s:StartModel(a:000)
endfunction

function s:StopTicker()
    :call s:DestroyTape()
    :call s:DestroyChart()
    :call s:ClearModel()
endfunction

function s:DestroyTicker()
    :call s:StopTicker()
    if s:chart
        let s:chart = 0
        :call s:DestroyChart()
    endif
    if s:tape
        let s:tape = 0
        :call s:DestroyTape()
    endif
    :call s:DestroyModel()
    :call s:DestroyInterface()

endfunction


" ================== COMMANDS/ENTRYPOINTS ======================

command -nargs=* Ticker :call s:CreateTicker(<f-args>)
command NoTicker :call s:DestroyTicker()
command TickerTape :call s:CreateTape()
command NoTickerTape :call s:DestroyTape()
command TickerChart :call s:CreateChart()
command NoTickerChart :call s:HideChart()
command NextTickerChart :call s:NextChart()
command PrevTickerChart :call s:PrevChart()

















