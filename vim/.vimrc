" =========================
" VSCodeVim Productivity VimRC
" =========================

" --- General ---
" Use space as leader
let mapleader=" "

" jj or jk to exit insert mode
inoremap jj <Esc>
inoremap jk <Esc>
nnoremap ZZ :wq<CR>

" Clear search highlights with double Esc
nnoremap <Esc><Esc> :nohlsearch<CR>

" --- Basic Save/Quit ---
nnoremap <leader>w :w<CR>          " Space + w = save
nnoremap <leader>q :q<CR>          " Space + q = quit
nnoremap <leader>x :wq<CR>         " Space + x = save & quit

" --- Buffer Navigation ---
nnoremap <leader>bn :bnext<CR>     " Next buffer
nnoremap <leader>bp :bprevious<CR> " Previous buffer
nnoremap <leader>bd :bd<CR>        " Close current buffer

" --- Split Window Navigation ---
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" --- Tabs ---
nnoremap <leader>tn :tabnew<CR>     " New tab
nnoremap <leader>tc :tabclose<CR>   " Close tab
nnoremap <leader>to :tabonly<CR>    " Close other tabs
nnoremap <leader>tm :tabmove        " Move current tab

" --- File Search & Navigation ---
nnoremap <leader>f :Files<CR>       " Open file search (requires fzf / CtrlP extension)
nnoremap <leader>rg :Rg<CR>         " Search in project (requires ripgrep / fzf)

" --- Git Integration ---
nnoremap <leader>gs :Git status<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gp :Git push<CR>
nnoremap <leader>gl :Git pull<CR>

" --- Commenting ---
nnoremap <leader>/ :call VSCodeNotify('editor.action.commentLine')<CR>
vnoremap <leader>/ :call VSCodeNotify('editor.action.commentLine')<CR>

" --- Searching ---
set hlsearch             " highlight matches
set incsearch            " incremental search
set ignorecase
set smartcase

" --- Visual Enhancements ---
set number               " line numbers
set relativenumber       " relative line numbers
set cursorline           " highlight current line
set showmatch            " highlight matching brackets

" --- Tabs & Indentation ---
set tabstop=4
set shiftwidth=4
set expandtab            " spaces instead of tabs

" --- Miscellaneous ---
set clipboard=unnamedplus  " Use system clipboard
