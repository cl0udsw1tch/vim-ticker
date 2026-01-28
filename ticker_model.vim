
" MODEL in MVC architecture. 

let s:job_handle = v:null
let s:n_bars = 20

let s:model_name = "__ticker_model__"
let s:model_handle = -1
let s:model = {}

" -------------------------- AUTOCOMMANDS ------------------------------

augroup Ticker#Model
    autocmd!
    autocmd User Ticker#CreateModel :call s:CreateModel()
    autocmd User Ticker#DestroyModel :call s:DestroyModel()
augroup END
            

" -------------------------- LIFECYCLE -----------------------------------

function s:CreateModel()
    if s:model_handle == -1
        let s:model_handle = bufadd("__ticker_model__")
        :call setbufvar(s:model_handle, "&buftype", "nofile")
        :call setbufvar(s:model_handle, "&bufhidden", "hide")
        :call setbufvar(s:model_handle, "&buflisted", 0)
        :call bufload(s:model_handle)   
        :call setbufvar(s:model_handle, "StartModel", funcref("<SID>StartModel"))
        :call setbufvar(s:model_handle, "ClearModel", funcref("<SID>ClearModel"))
       
        :call setbufvar(s:model_handle, "GetLastPrice", funcref("<SID>GetLastPrice"))
        :call setbufvar(s:model_handle, "GetStreamItemVal", funcref("<SID>GetStreamItemVal")),           :call setbufvar(s:model_handle, "StreamIter", funcref("<SID>StreamIter"))
        :call setbufvar(s:model_handle, "StreamIterIsValid", funcref("<SID>StreamIterIsValid"))
    endif   
    :call s:ClearModel() 
endfunction

function s:StartModel(tickers)
    :call s:SetTickers(a:tickers)
    :call s:GetPrevClose()
    :call s:GetPrices()
endfunction 

function s:ClearModel()
    :call s:StopJob()
    let s:model = {
                \"n_tickers": 0,
                \"n_bars": s:n_bars,
                \"tickers": [],
                \"price_data": {},
                \}
    :call setbufvar(s:model_handle, "model", s:model)
endfunction

function s:DestroyModel()
    if s:model_handle != -1
        :call s:ClearModel()
        :execute 'bwipeout' s:model_handle 
        let s:model_handle = -1
    endif
endfunction

" ------------------------- UTILITY,INTERFACE ------------------------------

function s:SetTickers(tickers)
    let s:model.tickers = a:tickers
    let s:model.n_tickers = len(a:tickers) 
    for ticker in a:tickers
        let s:model.price_data[ticker] = {"prev_close": -1, "prices": s:Stream(), "last": s:StreamItem()}
    endfor 
endfunction

function s:GetPrevClose()
    echo "Getting prev close..."
    let subprocess_str = s:PrevCloseSubProcessCode()
    let cmd = ["python3", "-u", "-c", "'" . subprocess_str . "'"] + s:model.tickers
    let res = system(join(cmd, " "))
    let close_arr = split(res, " ")
    let i = 0
    for ticker in s:model.tickers
        let s:model.price_data[ticker].prev_close = close_arr[i] == "-1" ? -1 : str2float(close_arr[i])
        let i+=1
    endfor
endfunction

function s:GetPrices()
    let subprocess_str = s:PriceSubProcessCode()
    let cmd = ["python3","-u", "-c", subprocess_str] +  s:model.tickers
    let s:job_handle = job_start(cmd, {
                \'out_cb': function("<SID>HandleResponse"), 
                \'err_cb': function("<SID>HandleError"), 
                \'exit_cb': function("<SID>HandleExit")
                \})
endfunction

function s:StopJob()
    if s:job_handle != v:null
        :call job_stop(s:job_handle)
        let s:job_handle = v:null
    endif
endfunction

function s:HandleResponse(ch,msg)
    let arr = split(a:msg," ")
    let name = arr[0]
    let price = str2float(arr[1])
    :call s:AddPrice(name, price)
endfunction

function s:HandleExit(job, exit_status)
    echo "Ticker exited with status: " . a:exit_status 
endfunction

function s:HandleError(ch, msg)
    echo "Ticker error: " . a:msg
endfunction


" ------------------------------- STREAM -------------------------------

let s:stream_item_map = {"MINUTE": 0, "OPEN": 1, "CLOSE":2, "HIGH": 3, "LOW": 4}

function s:Stream()
    let r = {
                \"idx": 0,
                \"head":0,
                \"buf": repeat([v:null], s:n_bars), 
                \"size": 0,
                \"capacity": s:n_bars
                \}
    return r
endfunction

function s:LastIdx(stream)
    if a:stream.size == 0
        return -1
    endif
    let last_idx = s:StreamPrevIdx(a:stream, a:stream.idx)
    return last_idx
endfunction

function s:Tail(stream)
    if a:stream.size == 0
        return v:null
    endif
    return a:stream.buf[s:LastIdx(a:stream)]
endfunction

function s:NextIdx(stream)
    return a:stream.idx
endfunction

function s:StreamPrevIdx(stream, idx)
    if idx == a:stream.head
        return -1
    endif
    return (a:idx -1 + a:stream.capacity ) % a:stream.capacity
endfunction

function s:Add(stream, stream_item)
    if a:stream.size == a:stream.capacity
        let a:stream.head = (a:stream.head + 1) % a:stream.capacity
    else
        let a:stream.size += 1
    endif

    let a:stream.buf[s:NextIdx(a:stream)] = a:stream_item
    let a:stream.idx = (a:stream.idx + 1) % a:stream.capacity 
endfunction

function s:GetStreamItemVal(stream_item, key)
    return a:stream_item[s:stream_item_map[a:key]]
endfunction

function s:SetStreamItemVal(stream_item, key, val)
    let a:stream_item[s:stream_item_map[a:key]] = a:val
endfunction

function s:StreamIterator(stream)
    let idx = s:model.LastIdx(a:stream)
    return {"idx": idx, "stream": a:stream}

endfunction

function s:StreamIterIsValid(stream_iter)
    return a:stream_iter.idx != -1
endfunction


function s:StreamIterPrev(stream_iter)
    let res = a:stream_iter.stream[a:stream_iter.idx]
    a:stream_iter.idx = s:StreamPrevIdx(a:stream, a:stream_iter.idx)
    return res
endfunction


" ------------------------- INTERFACE ----------------------------

function s:StreamItem()
    return [-1, -1, -1, -1, -1]
endfunction

function s:GetLast(ticker)
    return s:model.price_data[a:ticker].last
endfunction

function s:SetLast(ticker, stream_item)
    let s:model.price_data[a:ticker].last = a:stream_item
endfunction

function s:GetLastVal(ticker, key)
    return s:GetStreamItemVal(s:GetLast(a:ticker),  a:key)
endfunction

function s:SetLastVal(ticker, key, val)
    :call s:SetStreamItemVal(s:model.price_data[a:ticker].last, a:key, a:val)
endfunction

function s:GetLastPrice(ticker)
    return s:GetLastVal(a:ticker, "CLOSE")
endfunction

function s:AddPrice(ticker, price)
    let stream = s:model.price_data[a:ticker].prices
    let minute = (localtime() / 60) * 60
    let last_minute = s:GetLastVal(a:ticker, "MINUTE")
   
    if last_minute == minute
        let prev_high = s:GetLastVal(a:ticker, "HIGH")
        let prev_low = s:GetLastVal(a:ticker, "LOW")
        let high = max([prev_high, a:price])
        let low = min([prev_low, a:price])
        let close = a:price
        :call s:SetLastVal(a:ticker, "CLOSE", close)
        :call s:SetLastVal(a:ticker, "LOW", low)
        :call s:SetLastVal(a:ticker, "HIGH", high)
    else
        let new_stream_item = s:StreamItem()
        :call s:SetStreamItemVal(new_stream_item, "OPEN", a:price)
        :call s:SetStreamItemVal(new_stream_item, "CLOSE", a:price)
        :call s:SetStreamItemVal(new_stream_item, "HIGH", a:price)
        :call s:SetStreamItemVal(new_stream_item, "LOW", a:price)
        :call s:SetStreamItemVal(new_stream_item, "MINUTE", minute)

        :call s:Add(stream, s:GetLast(a:ticker))
        :call s:SetLast(a:ticker, new_stream_item)
    endif
endfunction


" ============================== SCRIPTS ===================================

function s:PrevCloseSubProcessCode()
    let cmd  = "import yfinance as yf\n"
    let cmd .= "import sys, signal\n"
    let cmd .= "sig_handle=lambda sig,frame: sys.exit(0)\n"
    let cmd .= "signal.signal(signal.SIGTERM,sig_handle)\n"
    let cmd .= "r=[]\n"
    let cmd .= "for name in sys.argv[1:]:\n"
    let cmd .= "\ttry:\n"
    let cmd .= "\t\tticker=yf.Ticker(name)\n"
    let cmd .= "\t\tinfo=ticker.fast_info\n"
    let cmd .= "\t\tclose=info[\"regularMarketPreviousClose\"]\n"
    let cmd .= "\t\tr.append(close)\n"
    let cmd .= "\texcept:\n"
    let cmd .= "\t\tr.append(-1)\n"
    let cmd .= "print(\" \".join(map(str,r)), flush=True)\n"
    return cmd
endfunction

function s:PriceSubProcessCode()
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
    let cmd .= "\t\t\tprint(name + \" \" + str(price), flush=True)\n"
    let cmd .= "\t\texcept:\n"
    let cmd .= "\t\t\tprint(name + \" -1\", flush=True)\n"
    let cmd .= "\ttime.sleep(5)\n"
    return cmd
endfunction


