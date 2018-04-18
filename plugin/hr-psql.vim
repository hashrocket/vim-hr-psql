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
  return lower_cased
endfunction

function! SetDatabase(channel, msg)
  let g:hr_psql_database_name = s:chomp(a:msg)
endfunction

function CatchError(channel, msg)
  echo a:msg
endfunction

function! s:LoadDatabase()
  let hr_psql_database_name = ''

  " check for rails db name
  if executable('ruby') && filereadable('config/database.yml')
    let command_list = ["ruby", "-ryaml", "-rerb", "-e", "puts YAML.load(ERB.new(File.read('config/database.yml')).result)['development']['database']"]

    call job_start(command_list, {"out_cb": "SetDatabase", "err_cb": "CatchError"})
  endif

  " check for elixir db name
  if empty(hr_psql_database_name) && executable('elixir') && filereadable('config/dev.exs')
    let hr_psql_database_name = system("elixir -e 'name = System.cwd! |> String.split(\"/\") |> Enum.reverse |> hd; db = get_in(Mix.Config.read!(\"config/dev.exs\"), [String.to_atom(name), :\"Elixir.#{Macro.camelize(name)}.Repo\", :database]); IO.puts(db)'")
    let hr_psql_database_name = s:chomp(hr_psql_database_name)
  endif
endfunction

function! s:PopulateTableNames()
  let command='psql ' . g:hr_psql_database_name . ' -X -q -t -c"SELECT c.relname FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = ''r'' AND n.nspname <> ''pg_catalog'' AND n.nspname <> ''information_schema'' AND n.nspname !~ ''^pg_toast'' AND pg_catalog.pg_table_is_visible(c.oid) ORDER BY 1;"'

  let command= s:chomp(command)
  let g:table_names=split(s:chomp(system(command)))
endfunction

if !has('nvim')
  call s:LoadDatabase()
endif
"call s:PopulateTableNames()

function! s:ShellPsqlVersionToVim()
  let command='psql ' . g:hr_psql_database_name . ' -X -q -t -c"select version();"'
  let command= s:chomp(command)
  echom s:chomp(system(command))
endfunction

function! s:PsqlTableDefinition(tablename)
  let findTableSql = "SELECT n.nspname || '.' || c.relname FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind in ('r', 'v') AND c.relname ~ '" . a:tablename . "' AND pg_catalog.pg_table_is_visible(c.oid) ORDER BY c.relkind, length(c.relname) ASC limit 1;"
  let findTableCommand='psql ' . g:hr_psql_database_name . ' -X -q -t -c"' . findTableSql . '"'
  let tableName=s:chomp(system(findTableCommand))

  let command='psql ' . g:hr_psql_database_name . ' -X -q -c"\d ' . tableName . '"'
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
  set ft=psql
endfunction

function! s:complete_table_names(arg_lead, cmd_line, cursor_pos)
  return filter(copy(g:table_names), 'v:val =~ "^'.a:arg_lead.'"')
endfunction

command Pgversion :call <SID>ShellPsqlVersionToVim()
command Pgreload :call <SID>LoadDatabase()
command Pgdatabase :echom g:hr_psql_database_name
command -nargs=* -complete=customlist,s:complete_table_names Pgtable :call <SID>PgtableWindow(<f-args>)

if !hasmapto('<Plug>hr_psql_pg_table_window')
  map <Leader>d  <Plug>hr_psql_pg_table_window
endif
nmap <Plug>hr_psql_pg_table_window  "pyiw:call <SID>PgtableWindow(@p)<cr>
