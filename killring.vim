" killring.vim - Mimics the Emacs Kill Ring

" version 0.1b

" init killRing
let s:killRing = []

" killRing size
let s:killRingSize = 30

" killRing offsets
let s:offset = { 'push': 0, 'pop': 0, 'reset': 0 }

" cursor column
let s:col = { 'end': 0, 'insert': 0, 'normal': 0 }

" cursor position
let s:cursor = { 'insert': [], 'insertLeavePre': [], 'normal': [] }

" push register to s:killRing, rotate when it reaches s:killRingSize
"
" register : register name
"
function! s:PushKillRing(register)
  let l:register = getreg(a:register)
  let l:register = substitute(l:register, '\n\+$', '', '')
  " do not push empty or single char
  if len(l:register) < 2 | return | endif
  " do not push  consecutive texts with same value
  if len(s:killRing) > 0 && l:register == s:killRing[s:offset['push']] | return | endif
  if len(s:killRing) < s:killRingSize
    call add(s:killRing, l:register)
    let s:offset['push'] = len(s:killRing) - 1
  else
    let s:offset['push'] = (s:offset['push'] + 1) % s:killRingSize
    let s:killRing[s:offset['push']] = l:register
  endif
  let s:offset['reset'] = 1
endfunction

" pop s:killRing
"
function! PopKillRing()
  call s:RotateKillRing(-1)
endfunction

" shift s:killRing
"
function! ShiftKillRing()
  call s:RotateKillRing(1)
endfunction

" rotate element from s:killRing
"
" offset : +1 (forward) or -1 (backward)
"
function! s:RotateKillRing(offset)
  " cursor column on insert mode
  let s:col['insert'] = s:cursor['insertLeavePre'][2]

  " cursor column on normal mode
  let s:col['normal'] = col('.')

  " go back to insert mode if s:killRing is empty
  if empty(s:killRing)
    " insert if insert and normal mode column is equal;
    " otherwise, append
    call feedkeys((s:col['insert'] == s:col['normal'] ? 'i' : 'a'), 'n')
    return
  endif

  " column on end of line
  let s:col['end'] = col('$')

  call s:Undo()

  " restore original register later
  let l:saved_register = getreg('"')

  " set to next s:killRingOffset and set its element on register
  call s:SetPopOffset(s:offset['pop'], a:offset)
  let l:buf = s:killRing[s:offset['pop']]
  call setreg('"', s:killRing[s:offset['pop']])

  " break undo sequence, start new change
  execute "normal! a\<c-g>u"

  call s:Paste()

  " restore register
  call setreg('"', l:saved_register)
endfunction

" replace the pasted text with an earlier batch of yanked text
"
function! s:Undo()
  if empty(s:cursor['normal'])
    let s:cursor['normal'] = getpos('.')
    let s:cursor['insert'] = s:cursor['insertLeavePre']
  else
    if s:RequireUndo()
      undo
    else
      let s:cursor['normal'] = getpos('.')
      let s:cursor['insert'] = s:cursor['insertLeavePre']
      let s:offset['reset'] = 1
    endif
  endif
endfunction

" return 1 if user did not move the cursor from the paste point;
" otherwise, return 0
"
function! s:RequireUndo()
  let l:cursor = getpos('.')
  let l:len = s:GetBufLen()

  " set cursor to paste point and move l:len times to the right
  call setpos('.', s:cursor['normal'])
  execute 'normal! ' . l:len . 'l'

  " set l:undo to 1 if user did not move the cursor from the paste point,
  " otherwise, set l:undo to 0
  let l:undo = l:cursor == getpos('.')

  " restore original paste point
  call setpos('.', l:cursor)

  return l:undo
endfunction

" length of s:killRing[s:offset['pop'] in normal mode
"
function! s:GetBufLen()
  let l:len = 0
  let l:buf = split(s:killRing[s:offset['pop']], '\n')
  for l:b in l:buf | let l:len += len(l:b) | endfor

  if s:cursor['insert'] == s:cursor['normal'] | let l:len -= 1 | endif

  return l:len
endfunction

" set s:offset['reset'] and s:offset['pop']
"
" position : current offset of s:killRingPop
" offset   : +1 (forward) or -1 (backward)
"
function! s:SetPopOffset(position, offset)
  if s:offset['reset']
    let s:offset['reset'] = 0
    let s:offset['pop'] = s:offset['push']
  else
    let l:position = a:position + a:offset
    if l:position < 0 | let l:position += len(s:killRing) | endif
    let l:position %= len(s:killRing)
    let s:offset['pop'] = l:position
  endif
endfunction

" paste register and go back to insert mode
"
function! s:Paste()
  " paste before the cursor if column is at the start or the end of line
  " otherwise, paste after the cursor
  let l:buf = split(s:killRing[s:offset['pop']], '\n')
  let l:len = len(l:buf[0])
  if len(l:buf) < 2
    let l:paste =
      \ (s:col['insert'] == 1 && s:col['normal'] == 1) ||
      \ (s:col['insert'] - l:len == 1)
      \ ? 'P' : 'p'
  else
    let l:paste =
      \ (s:col['insert'] == 1 && s:col['normal'] == 1) ||
      \ (s:col['end'] - l:len - 1 == s:col['normal']) ||
      \ (s:cursor['insert'][2] == 1 && s:cursor['normal'][2] == 1) ||
      \ (s:cursor['insert'][2] == 1 && col('$') == 2)
      \ ? 'P' : 'p'
  endif

  " append if cursor is on the start or the end of line;
  " otherwise, insert
  let l:insert =
    \ (s:col['insert'] == s:col['normal'] && s:col['insert'] > 1) || s:col['insert'] == s:col['end'] ? 'a' : 'i'

  execute 'normal! g' . l:paste
  call feedkeys(l:insert, 'n')
endfunction

" mimic emacs backward-kill-word
"
function! BackwardKillWord()
  " move cursor to where it was in insert mode
  execute 'normal! `^'

  " use 'vd' if cursor is on the start of line;
  " otherwise, use 'dvb'
  let c = col('.') == 1 ? 'vb' : 'dvb'
  call s:Kill(c)

  " go back to insert mode
  call feedkeys('i', 'n')
endfunction

" mimic emacs kill-word
"
function! ForwardKillWord()
  " move cursor to where it was in insert mode
  execute 'normal! `^'

  call s:Kill(c . 'de')

  " go back to insert mode
  call feedkeys('i', 'n')
endfunction

" restore regsiter after pushing deleted text to s:killRing
"
function! s:Kill(c)
  let l:saved_register = getreg('"')
  execute 'normal! ' . a:c
  call setreg('"', l:saved_register)
endfunction

" set s:killRingSize
"
" killRingSize : desired value for s:killRingSize in int
"
function! SetKillRingSize(killRingSize)
  let s:killRingSize = a:killRingSize
  " if s:killRing shrank
  if a:killRingSize < len(s:killRing)
    let l:reduceSize = a:killRingSize - 1
    let s:killRing = s:killRing[0:l:reduceSize]
    " set s:offset['push'] and s:offset['pop'] to the first element
    if s:offset['push'] > l:reduceSize | let s:offset['push'] = 0 | endif
    if s:offset['pop'] > l:reduceSize | let s:offset['pop'] = 0 | endif
  endif
endfunction

" browse s:killRing
"
function! BrowseKillRing()
  echo reverse(s:killRing)
endfunction

" echo s:killRingSize
"
function! GetKillRingSize()
  echo s:killRingSize
endfunction

" autocommand
if exists('##InsertLeavePre') && exists('##TextYankPost')
  augroup kill_ring_group
    autocmd!
    autocmd TextYankPost * call s:PushKillRing(v:register)
    autocmd InsertLeavePre * let s:cursor['insertLeavePre'] = getpos('.')
  augroup END
endif

" map pop s:killRing
if mapcheck('<m-y>', 'i') == ''
  inoremap <silent> <m-y> <esc>:call PopKillRing()<cr>
endif

" map shift s:killRing
if mapcheck('<m-Y>', 'i') == ''
  inoremap <silent> <m-Y> <esc>:call ShiftKillRing()<cr>
endif

" map backward-kill-word
if mapcheck('<m-bs>', 'i') == ''
  inoremap <silent> <m-bs> <esc>:call BackwardKillWord()<cr>
endif

" map kill-word
if mapcheck('<m-d>', 'i') == ''
  inoremap <silent> <m-d> <esc>:call ForwardKillWord()<cr>
endif
