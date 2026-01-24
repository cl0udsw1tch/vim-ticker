

let s:n_tickers = 0
let s:tickers = []
let s:prices = {}
let s:ticker_tape = "EMPTY"
let s:ticker_rotate_handle = -1
let s:ticker_head_offset = 0
let s:ticker_head = 0
let s:tape_len = 50
let s:rotate_hz = 5
let s:max_tickers = 10
let s:job_handle = v:null

let s:chart_pad_x = 8
let s:chart_pad_y = 4



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



" =============================================================== " 
function s:GetSubProcessCode()
    let cmd  = "import yfinance as yf\n"
    let cmd .= "import sys, time, signal\n"
    let cmd .= "sig_handle=lambda sig,frame: sys.exit(0)\n"
    let cmd .= "signal.signal(signal.SIGTERM,sig_handle)\n"
    let cmd .= "while True:\n"
    let cmd .= "\tfor name in sys.argv[1:]:\n"
    let cmd .= "\t\ttry:\n"
    let cmd .= "\t\t\tticker=yf.Ticker(name)\n"
    let cmd .= "\t\t\tinfo=ticker.fast_info\n"
    let cmd .= "\t\t\tprice=info[\"last_price\"]\n"
    let cmd .= "\t\t\tclose=info[\"regularMarketPreviousClose\"]\n"
    let cmd .= "\t\t\tr=[name,price,(price-close)/close]\n"
    let cmd .= "\t\t\tprint(\" \".join(map(str,r)), flush=True)\n"
    let cmd .= "\t\texcept:\n"
    let cmd .= "\t\t\tr=[name,-1,0]\n"
    let cmd .= "\t\t\tprint(\" \".join(map(str, r)), flush=True)\n"
    let cmd .= "\ttime.sleep(5)\n"
    return cmd
endfunction


function s:ExecuteSubProcess()
    let subprocess_str = s:GetSubProcessCode()
    let cmd = ["python3","-u", "-c", subprocess_str] +  s:tickers
    let s:job_handle = job_start(cmd, {'out_cb': function("<SID>HandleResponse"), 'err_cb': function("<SID>HandleError"), 'exit_cb': function("<SID>HandleExit")})
endfunction

function s:HandleResponse(ch,msg)
    let arr = split(a:msg," ")
    let name = arr[0]
    let price = str2float(arr[1])
    let delta = str2float(arr[2])
    let fprice = s:FormatPrice(price)
    let fdelta = s:FormatDelta(delta)
    let change = 0
    if delta > 0
        let change = 1
    elseif delta < 0
        let change = -1
    endif
    let s:prices[name]={"name":name,"price":fprice,"delta":fdelta,"change":change}
endfunction

function s:HandleExit(job, exit_status)
    echo "Ticker exited with status: " . a:exit_status 
endfunction

function s:HandleError(ch, msg)
    echo "Ticker error: " . a:msg
endfunction
" =============================================================== " 


" =============================================================== " 
" This could be uneccesary but I don't wanna mess up the user's statusline

if !exists('s:base_statusline')
    let s:base_statusline=''
endif

function s:SetBaseStatusLine(timerId) 
    let s:base_statusline = &statusline
endfunction
    
augroup Ticker#CaptureStatusLine
    autocmd!
    autocmd VimEnter * :call timer_start(200, function('<SID>SetBaseStatusLine'))
augroup END
" =============================================================== " 


" =============================================================== " 
function s:SetTickers(tickers)
    let s:tickers = a:tickers
    let s:n_tickers = len(a:tickers) 
    for ticker in a:tickers
        let s:prices[ticker]={"name":ticker, "price":-1, "delta": 0, "change":0}
    endfor 
endfunction


function s:FormatPrice(raw_float)
    let formatted_price = printf("%.2f", a:raw_float) 
    return formatted_price
endfunction

function s:FormatDelta(raw_float)
    let fdelta = printf("%.2f", abs(a:raw_float)*100) . "\uFE6A"
    return fdelta
endfunction


function s:RotateTickerTape(timerId)
    let s:ticker_tape = ""
    let ticker_idx = s:ticker_head
    let j0 = s:ticker_head_offset
    let j = s:ticker_head_offset
    let char_count = 0
    let ticker0 = s:tickers[ticker_idx]
    let name_token0 = ticker0 . " "
    let price_token0 = s:prices[ticker0]['price'] . " "
    let change0 = s:prices[ticker0]['change']
    let delta_token0 = "(" . s:change_sym_map[change0] .  s:prices[ticker0]['delta'] . ") "
    let m_name0 = strchars(name_token0)
    let m_price0 = strchars(price_token0)
    let m_delta0 = strchars(delta_token0)
    let hl_tag0 = s:HL_Map[change0]
    if j<m_name0
        let s:ticker_tape .= s:HL_Map[0]
    elseif j>=m_name0
        let s:ticker_tape .= hl_tag0
    endif
    "let j=(j+1)%(m_name0+m_price0+m_delta0)
    if j0==0
        let j+=1
    elseif j0==m_name0
        let j+=1
    endif
    while char_count<s:tape_len
        let ticker = s:tickers[ticker_idx]
        let name_token = ticker . " "
        let price_token = s:prices[ticker]['price'] . " "   
        let change=s:prices[ticker]['change']
        let delta_token = "(" . s:change_sym_map[change] . s:prices[ticker]['delta'] . ") "
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
            let ticker_idx = (ticker_idx+1)%s:n_tickers
        endif
    endwhile
    let s:ticker_head_offset=(j0+1)%(m_name0+m_price0+m_delta0)
    if s:ticker_head_offset==0
        let s:ticker_head=(s:ticker_head+1)%s:n_tickers
    endif
    :call s:UpdateStatusLine()
endfunction


function s:UpdateStatusLine()
    let &statusline = s:base_statusline . "%=" . s:ticker_tape
endfunction


function s:UpdateTickers()
    :call s:ExecuteSubProcess()
endfunction

" =============================================================== " 


" =============================================================== " 
function s:Ticker(...)
    if a:0 > s:max_tickers
        echo "Too many tickers, maximum 10 allowed"
        return
    endif 

    :call s:ClearTicker()
    :call s:SetTickers(a:000)
    :call s:UpdateTickers()
    let s:ticker_rotate_handle = timer_start(1000/s:rotate_hz, function("<SID>RotateTickerTape"), {'repeat': -1}) 
endfunction

 
function s:ClearTicker()
    let &statusline=s:base_statusline
    if s:job_handle isnot v:null
        :call job_stop(s:job_handle)
        let s:job_handle=v:null

        :call timer_stop(s:ticker_rotate_handle)
        let s:ticker_rotate_handle=-1
        let s:ticker_head_offset=0
        let s:ticker_head=0
    endif
endfunction

augroup Ticker#ClearTicker
autocmd!
autocmd VimLeavePre * :call <SID>ClearTicker() 
augroup END
" =============================================================== " 

command -nargs=* TickerTape :call call(function("<SID>Ticker"), split(<q-args>, " "))
command NoTickerTape :call <SID>ClearTicker()



" =============================================================== " 


function s:CreateChart()
    let minwidth = &columns - 2 * s:chart_pad_x
    let minheight = &lines - 2 * s:chart_pad_y
    let maxwidth = minwidth
    let maxheight = minheight

    let s:chart_bufnr = bufnr("ticker_chart", 1)    
    :call setbufvar(s:chart_bufnr, '&buftype', 'popup')
    :call setbufvar(s:chart_bufnr, '&readonly', 1)
    :call setbufvar(s:chart_bufnr, '&bufhidden', 'wipe')
    :call setbufvar(s:chart_bufnr, '&swapfile', 0)
    :call setbufvar(s:chart_bufnr, '&modifiable', 1)


    let s:chart_winid = popup_create(s:chart_bufnr, {'pos': 'center', 'minwidth': minwidth, 'maxwidth': maxwidth, 'minheight': minheight, 'maxheight': maxheight, 'close': 'button'})

endfunction

function s:UpdateChart()

endfunction



function s:CloseChart()
    :call popup_close(s:chart_winid)

endfunction


command! TickerChart :call s:CreateChart()
command! NoTickerChart :call s:CloseChart()












" =============================================================== " 









