" killring.vim - Mimics the Emacs Kill Ring

" version 0.1b

" init killRing
let s:killRing = []

" killRing size
let s:killRingSize = 30

" killRing offsets
let s:offset = { 'push': 0, 'pop': 0, 'reset': 0 }

" flags
let s:flag = { 'pastedOnEOL': 0 }

" length of line to be pasted
let s:pasteOnLineLen = 0

" cursor column
let s:col = { 'insert': 0, 'normal': 0, 'end': 0 }

" previous cursor position
let s:cursor = []

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
  let s:col = {}

  " column in normal mode
  let s:col['normal'] = col('.')

  " column at the end of the line
  let s:col['end'] = col('$') - 1

  " move cursor to where it was in insert mode
  execute 'normal! `^'

  " column in insert mode
  let s:col['insert'] = s:col['normal'] + s:col['normal'] - col('.')

  " go back to insert mode if s:killRing is empty
  if empty(s:killRing)
    " append if normal mode col is at the end of the line;
    " otherwise, insert
    let c = (s:col['insert'] == s:col['normal'] && s:col['insert'] == s:col['end']) ? 'a' : 'i'
    call feedkeys(c, 'n')
    return
  endif

  call s:Undo()

  " flag paste on empty line
  let s:pasteOnLineLen = col('$')

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

  " flag pasted on EOL
  let s:flag['pastedOnEOL'] = s:col['insert'] == s:col['normal']
endfunction

" replace the pasted text with an earlier batch of yanked text
"
function! s:Undo()
  if empty(s:cursor)
    let s:cursor = getpos('.')
  else
    if s:RequireUndo()
      undo
    else
      let s:cursor = getpos('.')
      let s:offset['reset'] = 1
    endif
  endif
endfunction

" return 1 if user did not move the cursor from the paste point;
" otherwise, return 0
"
function! s:RequireUndo()
  let l:cursor = getpos('.')

  " insert mode and normal mode column offset
  let l:offset = s:col['normal'] - s:col['insert']

  " do not undo when current and previous cursor is in the same position
  if l:cursor == s:cursor | return 0 | endif

  " do not undo when current and previous cursor is at the beginning of the line
  if l:cursor[2] == 1 && s:cursor[2] == 1 | return 0 | endif

  " do not undo if previously pasted on EOL and insert mode cusor is on EOL
  if s:flag['pastedOnEOL'] == 0 && l:offset == 0 | return 0 | endif

  let l:len = 0
  let l:buf = split(s:killRing[s:offset['pop']], '\n')
  for b in l:buf | let l:len += len(b) | endfor

  " l:len - 1 when cursor is at the beginning of the line
  if ((l:cursor[2] - l:len < 1) || (l:cursor[2] - l:len == 1 && l:offset == 0)) &&
    \ (s:pasteOnLineLen != 2) | let l:len -= 1 | endif

  " multi-line l:buf requires additional l:len handling
  if len(l:buf) > 1
    let l:len = l:len + len(l:buf) - 1
    if (s:pasteOnLineLen == 1 || s:pasteOnLineLen == 2) | let l:len -= 1 | endif
  endif

  " set cursor to paste point and move l:len times to the right
  call setpos('.', s:cursor)
  execute 'normal! ' . l:len . 'l'

  " set l:undo to 1 if user did not move the cursor from the paste point,
  " otherwise, set l:undo to 0
  let l:undo = l:cursor == getpos('.')

  " restore original paste point
  call setpos('.', l:cursor)

  return l:undo
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
  " default paste and insert command
  let l:paste = 'P'
  let l:insert = 'i'

  " char on insert mode cursor
  let l:c = matchstr(getline('.'), '\%' . s:col['insert'] . 'c.')

  " paste and insert command depends on the following conditions
  if (s:col['insert'] == s:col['normal']) &&
    \ (l:c == '' || s:col['insert'] > 1 && s:col['insert'] == s:col['end'] || col('$') == 2)
    let l:paste = 'p'
    let l:insert = 'a'
  endif

  execute 'normal! g' . l:paste
  call feedkeys(l:insert, 'n')
endfunction

" mimic emacs backward-kill-word
"
function! BackwardKillWord()
  " move cursor to where it was in insert mode
  execute 'normal! `^'

  " use 'vd' if cursor is at the beginning of the line;
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

" restore regsiter after pushiing deleted text to s:killRing
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
if exists('##TextYankPost')
  augroup kill_ring_group
    autocmd!
    autocmd TextYankPost * call s:PushKillRing(v:register)
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
