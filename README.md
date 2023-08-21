# killring.vim

killring.vim is a Vim plugin that mimics the Emacs Kill Ring in insert mode.\
It assembles blocks of texts based on registers.\
It discards registers with consecutive text with the same value or a single character text.

## Requirement
The plugin requires support for InsertLeavePre and TextYankPost auto command.\
The following commands return 1 if the auto command is available; otherwise, it returns 0.

```vim
:echo exists('##InsertLeavePre')
:echo exists('##TextYankPost')
```

## Installation
Clone the repository.
```bash
git clone https://github.com/shuple/vim-killring.git
```

Source vim-killring/killring.vim
```vim
:source vim-killring/killring.vim
```

## Usage
The killring adds 4 key mappings in insert mode.

```m-y``` - pop copied text from the Kill Ring\
```m-Y``` - shift copied text from the Kill Ring

These keys replace the text just pasted with an earlier batch of yanked or deleted text by pressing the key again.\
The pointer resets to the head or tail, depending on its direction when reaching the first or last element.\
It moves the pointer to the most recent block if the cursor moves from the previous paste position.

```m-bs``` - mimics the Emacs backward-kill-word\
```m-d``` - mimics the Emacs kill-word

These keys push the text into the Kill Ring.

## Key Remapping
Remap pop or shift.
```vim
iunmap <m-y>
inoremap <silent> <m-y> <esc>:call PopKillRing()<cr>
iunmap <m-Y>
inoremap <silent> <m-Y> <esc>:call ShiftKillRing()<cr>
```

Remap backward-kill-word or kill-word.
```vim
iunmap <m-bs>
inoremap <silent> <m-bs> <esc>:call BackwardKillWord()<cr>
iunmap <m-d>
inoremap <silent> <m-d> <esc>:call ForwardKillWord()<cr>
```

## Function
Browse the Kill Ring.
```vim
:call BrowseKillRing()
```

Set Kill Ring size.
```vim
:call SetKillRingSize(30)
```

## Changelog
##### 0.1a (2020-10-31)
- Initial Alpha Release.
