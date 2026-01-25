


highlight! GREEN_BAR cterm=bold ctermfg=Magenta ctermbg=Black guibg=#000000 guifg=#123456
highlight! RED_BAR cterm=bold ctermfg=Red ctermbg=Black guibg=#000000 guifg=#FF0000
 
let s:chart_buf_handle = -1










function CreateMatchByLine() 
    let b:line_match_ids=[]
    let green_cols=[]
    let red_cols=[]
    let i=1 
    while i<=&columns
      if i%2==0
          :call add(green_cols,[0,i])
      else
          :call add(red_cols,[0,i])
      endif
      let i+=1
    endwhile
      
    let line=1
    while line<=&lines
        let line_green_id=matchaddpos("GREEN_BAR", map(green_cols, '[line, v:val[1]]'))
        let line_red_id=matchaddpos("RED_BAR", map(red_cols, '[line, v:val[1]]'))
        :call add(b:line_match_ids, [line_green_id,line_red_id])
        let line+=1
    endwhile
endfunction


function DeleteMatchByLine()
    for match_pair in b:line_match_ids
        let green_match=match_pair[0]
        let red_match=match_pair[1]
        :call matchdelete(green_match)
        :call matchdelete(red_match)
    endfor
endfunction


function CreateChartBuf()
    let s:chart_buf_handle = bufadd("ticker_chart")
    :call setbufvar(s:chart_buf_handle, "&buftype", "nofile")
    :call setbufvar(s:chart_buf_handle, "&bufhidden", "hide")
    :call setbufvar(s:chart_buf_handle, "&filetype", "ticker_chart")
    :call bufload(s:chart_buf_handle)   
endfunction

function DeleteChartBuf()
    if bufexists(s:chart_buf_handle) 
        :call DeleteMatchByLine()
        :call execute('bd' . " " . string(s:chart_buf_handle))
        let s:chart_buf_handle=-1
    endif
endfunction

function WriteChartBuf()

endfunction

function UpdateChartBuf()
    
endfunction




function ShowChart()
    :call execute("b " . string(s:chart_buf_handle))
endfunction


function HideChart()
    :bprevious  
endfunction








