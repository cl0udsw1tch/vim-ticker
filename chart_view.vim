" CHART VIEW
highlight! HL_GREEN_BAR cterm=bold ctermbg=Black ctermfg=Green guibg=#000000 guifg=#00FF00
highlight! HL_RED_BAR cterm=bold ctermbg=Black ctermfg=Red guibg=#000000 guifg=#FF0000
highlight! HL_CHART cterm=NONE ctermbg=Black ctermfg=NONE guibg=#000000 guifg=NONE
highlight! HL_BORDER cterm=NONE ctermbg=Black ctermfg=NONE guibg=#000000 guifg=NONE
highlight! HL_NONE cterm=NONE ctermbg=NONE ctermfg=NONE guibg=NONE guifg=NONE
let s:HL_MAP = ["HL_RED_BAR", "HL_GREEN_BAR"]
let s:HL_ON = 1

let s:buf_handle = -1
let s:win_handle = -1
let s:ticker = " "
let s:lines = 25
let s:line_grps = float2nr(ceil(s:lines / 8.0))
let s:cols = 10
let s:content = repeat([" "], s:lines+1) " low->high prices, iterative backwards on render
let s:maxPrice = -1
let s:minPrice = pow(2, 32)
let s:minute = -1
let s:line_interval = -1

let s:match_state = repeat([-1], s:cols+1) " SENTINEL @ idx=0
let s:match_pos = repeat([v:null], s:cols+1)
let s:match_ids = repeat([v:null], s:cols+1)
let col = 1
while col < s:cols + 1
	let grouped_pos = repeat([v:null], s:line_grps)
    let grouped_matches = repeat([-1], s:line_grps)
	let grp = 0
	while grp < s:line_grps
		let grp_size = 8
		if 8*(grp+1) > s:lines
			let grp_size = s:lines - 8*grp
		endif
		let grouped_pos[grp] = map(repeat([v:null], grp_size), "[grp*8 + v:key+1, col]")
		let grp+=1
	endwhile
	let s:match_pos[col] = grouped_pos
    let s:match_ids[col] = grouped_matches
	let col += 1
endwhile

let s:min_handle=-1
let s:max_handle=-1
let s:t0_handle=-1
let s:t1_handle=1
let s:interface_name = "__ticker_controller__"
let s:interface_handle = -1
let s:api = {}


" ----------------------------- AUTOCOMMANDS ----------------------------
augroup Ticker#ChartView
autocmd!
autocmd User Ticker#ChartControllerReady :call s:CreateChartView()
augroup END

" ----------------------------- INTERFACE --------------------------------

function s:CreateChartView()
    let s:interface_handle = bufnr(s:interface_name)
    let s:api = getbufvar(s:interface_handle, "api")
    let s:api.ChartView = {
                \"UpdateChartView": funcref("<SID>UpdateChartView"),
                \"DestroyChartView": funcref("<SID>DestroyChartView"),
                \"HideChart": funcref("<SID>HideChart"),
                \"ShowChart": funcref("<SID>ShowChart"),
                \"ChangeChart": funcref("<SID>ChangeChart"),
                \}
    let s:buf_handle = bufadd("ticker_chart")
    :call setbufvar(s:buf_handle, "&buflisted", 0)
    :call setbufvar(s:buf_handle, "&buftype", "nofile")
    :call setbufvar(s:buf_handle, "&readonly", 0)
    :call setbufvar(s:buf_handle, "&modifiable", 1)
    :call bufload(s:buf_handle)
    let s:win_handle = popup_create(s:buf_handle, {
                \'pos':'topright',
		        \'col': &columns,
		        \'line': 1,
                \'minWidth': s:cols,
                \'maxWidth': s:cols,
                \'minHeight': s:lines,
                \'maxHeight': s:lines,
		        \'padding': [2,2,2,2],
		        \'border': [2,2,2,2],
		        \'highlight': 'HL_CHART',
                \'borderhighlight': ["HL_BORDER"],
                \'title': s:ticker
                \})

    let win_pos = popup_getpos(s:win_handle)
    let s:min_handle = popup_create("min_price",{
                \"pos": "topright",
                \'col': &columns - s:cols - 8,
                \'line': 4+s:lines,
                \'highlight': "HL_NONE",
                \})
    let s:max_handle = popup_create("max_price",{
                \"pos": "topright",
                \'col': &columns - s:cols - 8,
                \'line': 4,
                \'highlight': "HL_NONE",
                \})
    let s:t0_handle = popup_create("t0_handle",{
                \'pos': 'topleft',
                \'col': &columns - s:cols - 4,
                \'line': s:lines + 8,
                \'highlight': "HL_NONE" 
                \})
    let s:t1_handle = popup_create("t1_handle", {
                \'pos': 'topleft',
                \'col': &columns - 4,
                \'line': s:lines+8,
                \'highlight': 'HL_NONE'
                \})
    :call popup_hide(s:win_handle)
    :call popup_hide(s:min_handle)
    :call popup_hide(s:max_handle)
    :call popup_hide(s:t0_handle)
    :call popup_hide(s:t1_handle)
endfunction

function s:UpdateChartView(ticker, bar_iter, last_bar)
    "bar_iter is a backwards iterator, with a PREV api method
    if a:ticker != s:ticker
        :call s:ChangeChart(a:ticker)
    endif
    let last_low = s:api.ChartController.GetBarVal(a:last_bar, "LOW")
    let last_high = s:api.ChartController.GetBarVal(a:last_bar, "HIGH")
    let last_minute = s:api.ChartController.GetBarVal(a:last_bar, "MINUTE")
    let last_open = s:api.ChartController.GetBarVal(a:last_bar, "OPEN")
    let last_close = s:api.ChartController.GetBarVal(a:last_bar, "CLOSE")
   
    let hl = last_close >= last_open 
    :call s:UpdateColHL(s:cols, hl)
    
    let newBounds = last_high > s:maxPrice || last_low < s:minPrice
    let newBar = last_minute > s:minute
    if newBounds
        :call s:ClearChartContent()
        let s:maxPrice = g:FloatMax([s:maxPrice, last_high])
        let s:minPrice = g:FloatMin([s:minPrice, last_low])
        let s:line_interval = (s:maxPrice-s:minPrice)/(s:lines+0.0)
    endif
    if newBar
        let s:t1 = strftime("%H:%M", last_minute)
        let s:t0 = strftime("%H:%M", last_minute - (s:cols - 1)*60)
    endif

    if !newBounds && !newBar
        :call s:UpdateLinesForBar(last_low, last_high, last_open, last_close, 1)
        :call s:FillContentPrefix()
        :call s:WriteContentToBuf()
        return 
    elseif !newBounds && newBar
        :call s:ShiftLines()
        :call s:UpdateLinesForBar(last_low, last_high, last_open, last_close, 1)
        :call s:FillContentPrefix()
        :call s:WriteContentToBuf()
        let s:minute = last_minute 
    elseif newBounds && !newBar
        :call s:UpdateLinesForBar(last_low, last_high, last_open, last_close, 1)
    elseif newBounds && newBar
        :call s:UpdateLinesForBar(last_low, last_high, last_open, last_close, 1)
        let s:minute = last_minute
    endif
   
    let bar_col = s:cols - 1
    while s:api.ChartController.BarIterIsValid(a:bar_iter) && bar_col > 0
        let bar = s:api.ChartController.BarIterPrev(a:bar_iter)
        let low = s:api.ChartController.GetBarVal(bar, "LOW")
        let high = s:api.ChartController.GetBarVal(bar, "HIGH")
        let open = s:api.ChartController.GetBarVal(bar, "OPEN")
        let close = s:api.ChartController.GetBarVal(bar, "CLOSE")
        let minute = s:api.ChartController.GetBarVal(bar, "MINUTE")
        if newBar
            let hl = close >= open
	        :call s:UpdateColHL(bar_col, hl)
    	endif 
        if newBounds
            :call s:UpdateLinesForBar(low, high, open, close, 0)
        endif
        let bar_col -= 1
    endwhile
    :call s:api.ChartController.BarIterReset(a:bar_iter)
    :call s:FillContentPrefix()
    :call s:WriteContentToBuf()
endfunction

function s:UpdateColHL(col, hl)
	if !s:HL_ON
		return
	endif

	if s:match_state[a:col] == -1
		:call s:AddColHLGrps(a:col, a:hl)
		let s:match_state[a:col] = a:hl
    elseif s:match_state[a:col] == a:hl
		" NO OP
    else
		:call s:DeleteColHLGrps(a:col)
		:call s:AddColHLGrps(a:col, a:hl)
   		let s:match_state[a:col] = a:hl
    endif
endfunction


function s:AddColHLGrps(col, hl)
	let grp = 0
	while grp < s:line_grps
		let s:match_ids[a:col][grp] = matchaddpos(s:HL_MAP[a:hl], s:match_pos[a:col][grp], 10, -1, {"window": s:win_handle})
	    let grp +=1
	endwhile
endfunction

function s:DeleteColHLGrps(col)
	let grp = 0
	while grp < s:line_grps
		:call matchdelete(s:match_ids[a:col][grp], s:win_handle)
		let s:match_ids[a:col][grp] = -1
		let grp +=1
	endwhile
endfunction

function s:UpdateLinesForBar(low, high, open, close, isLast)
    let line = 1
    while line <= s:lines
        let c = s:BarChar(line, a:low, a:high, a:open, a:close)
        let s:content[line] = a:isLast ? s:content[line][:-2] . c : c . s:content[line]
        let line+=1 
    endwhile
endfunction

function s:ShiftLines()
    let line = 1
    while line <= s:lines
        let s:content[line] = s:content[line][1:] . " "
        let line +=1
    endwhile
endfunction

function s:BarChar(line, low, high, open, close)
    if g:IndexOf([a:low, a:high, a:open, a:close], 1.0) != -1
        return " " 
    endif
    let low_line = s:PriceToLine(a:low)
    let min_box = s:PriceToLine(g:FloatMin([a:open, a:close]))
    let max_box = s:PriceToLine(g:FloatMax([a:open, a:close]))
    let high_line = s:PriceToLine(a:high)
    "let change = 1
    "if g:FloatMax([a:open, a:close]) == a:open
    "    let change = -1
    "endif

    if a:line < low_line
        return " "
    elseif a:line < min_box
        return "|"
    elseif a:line >= min_box && a:line <= max_box
        return "#" 
    elseif a:line > max_box && a:line < high_line
        return "|"
    else
        return " "
    endif
endfunction

function s:PriceToLine(price)
    return (a:price - s:minPrice) / (s:line_interval + 0.0) + 1.0
endfunction

function s:LineToLoPrice(line)
    return s:minPrice + s:line_interval * (a:line - 1)
endfunction

function s:LineToHiPrice(line)
    return s:LineToLoPrice(a:line) + s:line_interval
endfunction

function s:FillContentPrefix()
    let line = 1
    while line <= s:lines
        let width = len(s:content[line])
        if width < s:cols
            let n_spaces = s:cols - width
            let s:content[line] = repeat(" ", n_spaces) . s:content[line]
        endif
        let line +=1
    endwhile
endfunction


function s:WriteContentToBuf()
    let line = 1
    while line <= s:lines
        :call setbufline(s:buf_handle, line, s:content[s:lines - line + 1]) 
        let line += 1
    endwhile
    :call popup_settext(s:min_handle, printf("%.2f", s:minPrice) . " ->")
    :call popup_settext(s:max_handle, printf("%.2f", s:maxPrice) . " ->")
    :call popup_settext(s:t0_handle, s:t0)
    :call popup_settext(s:t1_handle, s:t1)
endfunction

function s:ClearChartView()
    :call s:ClearChartContent()
    :call s:ClearChartHLMatches()
    let s:ticker = " "
    let s:minute = -1
    let s:maxPrice = -1
    let s:minPrice = pow(2, 32)
endfunction

function s:ClearChartContent()
    let s:content = repeat([" "], s:lines+1)
endfunction

function s:ClearChartHLMatches()
	if !s:HL_ON
		return
	endif

    let col = 1
    while col < s:cols + 1
		let hl = s:match_state[col]
		if hl == -1
			" NO OP
		else
			:call s:DeleteColHLGrps(col) 
            let s:match_state[col] = -1
		endif 
		let col += 1
	endwhile
endfunction

function s:ShowChart()
    :call popup_show(s:win_handle)
    :call popup_show(s:min_handle)
    :call popup_show(s:max_handle)
    :call popup_show(s:t0_handle)
    :call popup_show(s:t1_handle)
endfunction

function s:HideChart()
    :call popup_hide(s:win_handle)
    :call popup_hide(s:min_handle)
    :call popup_hide(s:max_handle)
    :call popup_hide(s:t0_handle)
    :call popup_hide(s:t1_handle)
endfunction

function s:ChangeChart(ticker)
    call s:ClearChartView()
    let s:ticker = a:ticker
    :call popup_setoptions(s:win_handle, {'title': s:ticker})
endfunction

function s:DestroyChartView()
    :call s:ClearChartView()
    :call s:ClearChartContent()
    if s:win_handle != -1
    :call popup_close(s:win_handle)
    :call popup_close(s:min_handle)
    :call popup_close(s:max_handle)
    :call popup_close(s:t0_handle)
    :call popup_close(s:t1_handle)
    endif
    let s:win_handle = -1
    let s:buf_handle = -1
    let s:min_handle = -1
    let s:max_handle = -1
    let s:t0_handle = -1
    let s:t1_handle = -1
endfunction
            









