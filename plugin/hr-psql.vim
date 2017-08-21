" hr-psql.vim - execute psql commands from vim
" Author: Chris Erin (hashrocket.com)
" Version: 0.1


if exists('g:loaded_vim_hr_psql')
  finish
endif
let g:loaded_vim_hr_psql = 1

function! s:chomp(str)
 return substitute(a:str, '\n\+$', '', '')
endfunction

function! s:tableize(str)
  let underscored_name = substitute(a:str, '\(\<\u\l\+\|\l\+\)\(\u\)', '\l\1_\l\2', 'g')
  let lower_cased = substitute(underscored_name, '\(\<\u\l\+\|\l\+\)', '\l\1', 'g')
  if lower_cased =~ 's$'
    let pluralized_name = lower_cased
  else
    let pluralized_name = lower_cased . 's'
  endif
  return pluralized_name
endfunction

let hr_psql_database_name = system("ruby -ryaml -e \"puts YAML.load_file('config/database.yml')['development']['database']\"")

let g:hr_psql_database_name = s:chomp(hr_psql_database_name)

function! s:ShellPsqlVersionToVim()
  let command='psql ' . g:hr_psql_database_name . ' -t -c"select version();"'
  let command= s:chomp(command)
  echom s:chomp(system(command))
endfunction

function! s:PsqlTableDefinition(tablename)
  let command='psql ' . g:hr_psql_database_name . ' -c"\d ' . s:tableize(a:tablename) . '"'
  let command= s:chomp(command)
  return s:chomp(system(command))
endfunction

function! s:PgtableWindow(tablename)
  let l:converted_tablename=s:tableize(a:tablename)
  if exists('g:hr_psql_buffer_number')
    silent! execute 'bwipeout' . g:hr_psql_buffer_number
  endif
  new
  let g:hr_psql_buffer_number = bufnr('%')
  call append(line('.'), split(s:PsqlTableDefinition(l:converted_tablename), '\n'))
  normal gg
  normal dd
  let l:window_size=line('$')
  execute('resize ' . l:window_size)
  setlocal bt=nofile bh=hide noswf ro
endfunction

command Pgversion :call <SID>ShellPsqlVersionToVim()
command Pgdatabase :echom g:hr_psql_database_name
command -nargs=* Pgtable :call <SID>PgtableWindow(<f-args>)

nnoremap <leader>d "zyiw:call <SID>PgtableWindow(@z)<cr>
