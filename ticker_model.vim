
" MODEL in MVC architecture. 

let s:job_handle = v:null
let s:n_bars = 10

let s:model_name = "__ticker_model__"
let s:model_handle = -1
let s:model = {}
let s:model_interface = {}
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
        
        let s:model_interface={
                    \"StartModel": funcref("<SID>StartModel"),
                    \"ClearModel": funcref("<SID>ClearModel"),
                    \"GetLastPrice": funcref("<SID>GetLastPrice"),
                    \"GetStreamItemVal": funcref("<SID>GetStreamItemVal"),
                    \"StreamIterator": funcref("<SID>StreamIterator"),
                    \"StreamIterIsValid": funcref("<SID>StreamIterIsValid"),
                    \"StreamIterPrev": funcref("<SID>StreamIterPrev"),
                    \"StreamIterReset": funcref("<SID>StreamIterReset"),
                    \}
        :call setbufvar(s:model_handle, "model_interface", s:model_interface)
        :call s:ClearModel()
    else
        :call s:ClearModel()
    endif
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
        let s:model.price_data[ticker] = {"prev_close": -1.0, "prices": s:Stream(), "last": s:StreamItem()}
    endfor 
endfunction

function s:GetPrevClose()
    let subprocess_str = s:PrevCloseSubProcessCode()
    let cmd = ["python3", "-u", "-c", "'" . subprocess_str . "'"] + s:model.tickers
    let res = system(join(cmd, " "))
    let close_arr = split(res, " ")
    let i = 0
    for ticker in s:model.tickers
        let s:model.price_data[ticker].prev_close = close_arr[i] == "-1" ? -1.0 : str2float(close_arr[i])
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
    "echo "Ticker exited with status: " . a:exit_status 
endfunction

function s:HandleError(ch, msg)
    "echo "Ticker error: " . a:msg
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
    let idx = s:LastIdx(a:stream)
    return {"idx": idx, "stream": a:stream}
endfunction

function s:StreamIterIsValid(stream_iter)
    if a:stream_iter.stream.size == 0
        return 0
    endif
    return a:stream_iter.idx != -1
endfunction

function s:StreamIterPrev(stream_iter)
    
    if a:stream_iter.idx == a:stream_iter.stream.idx
        let a:stream_iter.idx = -1
        return a:stream_iter.stream.buf[a:stream_iter.stream.idx]
    endif
    let stream = a:stream_iter.stream
    let res = stream.buf[a:stream_iter.idx]
    let a:stream_iter.idx = s:StreamPrevIdx(a:stream_iter.stream, a:stream_iter.idx)
    if stream.buf[a:stream_iter.idx] is v:null
        let a:stream_iter.idx = -1
    endif
    return res
endfunction

function s:StreamIterReset(stream_iter)
    let a:stream_iter.idx = s:LastIdx(a:stream_iter.stream)
endfunction

" ------------------------- INTERFACE ----------------------------

function s:StreamItem()
    return [-1, -1.0, -1.0, -1.0, -1.0]
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
        let high = g:FloatMax([prev_high, a:price])
        let low = g:FloatMin([prev_low, a:price])
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

    if getenv("vim_ticker_debug")
        return s:DEBUG_PrevCloseSubProcessCode()
    endif

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
    let cmd .= "\t\tr.append(-1.0)\n"
    let cmd .= "print(\" \".join(map(str,r)), flush=True)\n"
    return cmd
endfunction

function s:PriceSubProcessCode()
    if getenv("vim_ticker_debug")
        return s:DEBUG_PriceSubProcessCode()
    endif
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
    let cmd .= "\t\t\tprint(name + \" -1.0\", flush=True)\n"
    let cmd .= "\ttime.sleep(1)\n"
    return cmd
endfunction

function s:DEBUG_PrevCloseSubProcessCode()
    let cmd  = "import sys\n"
    let cmd .= "r=[str(100.0*i) for i in range(1, len(sys.argv))]\n"
    let cmd .= "print(\" \".join(map(str, r)), flush=True)\n"
    return cmd
endfunction

function s:DEBUG_PriceSubProcessCode()
    let cmd  = "import sys, time, signal, random\n"
    let cmd .= "sig_handle=lambda sig,frame: sys.exit(0)\n"
    let cmd .= "signal.signal(signal.SIGTERM,sig_handle)\n"
    let cmd .= "r=[100.0*i for i in range(1, len(sys.argv))]\n"
    let cmd .= "while True:\n"
    let cmd .= "\tfor i,name in enumerate(sys.argv[1:]):\n"
    let cmd .= "\t\tm1,m2=100.0*(i+1)-50, 100.0*(i+1)+50\n"
    let cmd .= "\t\tr[i] += random.randint(-2, 2)\n"
    let cmd .= "\t\tr[i]=min(max(r[i],m1), m2)\n"
    let cmd .= "\t\tprint(name + \" \" + str(r[i]), flush=True)\n"
    let cmd .= "\ttime.sleep(1)\n"
    return cmd
endfunction




" ====================== Test Suite ======================

function! s:AssertEqual(actual, expected, msg)
    if a:actual == a:expected
        echom "OK: " .. a:msg
    else
        echom "FAIL: " .. a:msg
        echom "  Expected: " .. string(a:expected)
        echom "  Got:      " .. string(a:actual)
    endif
endfunction

function! s:AssertNotNull(val, msg)
    if a:val isnot# v:null
        echom "OK: " .. a:msg
    else
        echom "FAIL: " .. a:msg .. " (got null)"
    endif
endfunction

function! s:RunStreamTests()
    echom "===== Starting stream + iterator tests ====="

    let s:n_bars = 5   " small size → easy to test wrap-around
    let stream = s:Stream()

    " 1. Empty stream
    call s:AssertEqual(stream.size, 0, "empty → size=0")
    call s:AssertEqual(s:LastIdx(stream), -1, "empty → LastIdx=-1")
    call s:AssertEqual(s:Tail(stream), v:null, "empty → Tail=null")

    let iter = s:StreamIterator(stream)
    call s:AssertEqual(s:StreamIterIsValid(iter), 0, "empty → iterator invalid")

    " 2. Add 1 item
    let item1 = s:StreamItem() | let item1[0] = 101 | let item1[1] = 100.5
    call s:Add(stream, item1)

    call s:AssertEqual(stream.size, 1, "size=1 after first add")
    call s:AssertEqual(s:Tail(stream)[0], 101, "Tail is newest (101)")
    call s:AssertEqual(s:GetStreamItemVal(s:Tail(stream), "MINUTE"), 101, "Tail MINUTE=101")

    " 3. Add 2 more → size=3 (not full yet)
    let item2 = s:StreamItem() | let item2[0] = 102 | let item2[2] = 101.2
    let item3 = s:StreamItem() | let item3[0] = 103 | let item3[3] = 102.8
    call s:Add(stream, item2)
    call s:Add(stream, item3)

    call s:AssertEqual(stream.size, 3, "size=3")
    call s:AssertEqual(s:Tail(stream)[0], 103, "newest is 103")

    " 4. Backward iteration (newest → oldest)
    let iter = s:StreamIterator(stream)
    call s:AssertNotNull(iter.idx, "iterator starts valid")

    let seen = []
    while s:StreamIterIsValid(iter)
        let item = s:StreamIterPrev(iter)
        call add(seen, item[0])
    endwhile

    call s:AssertEqual(seen, [103,102,101], "backward order: 103→102→101")

    " 5. Fill to capacity (5 items)
    let item4 = s:StreamItem() | let item4[0] = 104
    let item5 = s:StreamItem() | let item5[0] = 105
    call s:Add(stream, item4)
    call s:Add(stream, item5)

    call s:AssertEqual(stream.size, 5, "size=5 (full)")
    call s:AssertEqual(s:Tail(stream)[0], 105, "newest=105")

    " 6. Add one more → overwrite oldest, size stays 5
    let item6 = s:StreamItem() | let item6[0] = 106
    call s:Add(stream, item6)

    call s:AssertEqual(stream.size, 5, "size stays 5 after overwrite")
    call s:AssertEqual(s:Tail(stream)[0], 106, "newest=106")

    " 7. Backward iteration after wrap-around
    let iter = s:StreamIterator(stream)
    let seen = []
    while s:StreamIterIsValid(iter)
        let item = s:StreamIterPrev(iter)
        call add(seen, item[0])
        if len(seen) == 5
            :call s:AssertEqual(iter.idx, -1, "Iterator in invalid state after 5 iterations")
        endif
    endwhile

    call s:AssertEqual(seen, [106,105,104,103,102], "backward after overwrite: 106→105→104→103→102")

    " 8. One more overwrite → check head movement
    let item7 = s:StreamItem() | let item7[0] = 107
    call s:Add(stream, item7)

    let iter = s:StreamIterator(stream)
    let seen = []
    while s:StreamIterIsValid(iter)
        call add(seen, s:StreamIterPrev(iter)[0])
    endwhile

    call s:AssertEqual(seen, [107,106,105,104,103], "final: 107→106→105→104→103")

    echom "===== Tests finished ====="
endfunction

" :call s:RunStreamTests()
