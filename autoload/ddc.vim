function! ddc#enable() abort
  " Dummy call
  silent! call denops#plugin#is_loaded('ddc')
  if !('*denops#plugin#is_loaded'->exists())
    call ddc#util#print_error('denops.vim is not released or too old.')
    return
  endif

  if denops#plugin#is_loaded('ddc')
    return
  endif

  if !has('patch-8.2.0662') && !has('nvim-0.8')
    call ddc#util#print_error(
          \ 'ddc requires Vim 8.2.0662+ or neovim 0.8.0+.')
    return
  endif

  augroup ddc
    autocmd!
    autocmd User DDCReady :
    autocmd InsertLeave * call ddc#hide('InsertLeave')
  augroup END

  " Force context_filetype call
  silent! call context_filetype#get_filetype()

  let g:ddc#_started = reltime()

  " Note: ddc.vim must be registered manually.
  autocmd ddc User DenopsReady silent! call ddc#_register()
  if 'g:loaded_denops'->exists() && denops#server#status() ==# 'running'
    silent! call ddc#_register()
  endif
endfunction
function! ddc#enable_cmdline_completion() abort
  call ddc#enable()

  augroup ddc-cmdline
    autocmd!
    autocmd CmdlineLeave <buffer> call ddc#hide('CmdlineLeave')
    autocmd CmdlineEnter <buffer> call ddc#_on_event('CmdlineEnter')
    autocmd CmdlineChanged <buffer>
          \ if getcmdtype() !=# '=' && getcmdtype() !=# '@' |
          \ call ddc#_on_event('CmdlineChanged') | endif
  augroup END
  if '##ModeChanged'->exists()
    autocmd ddc-cmdline ModeChanged *:n
          \ call ddc#disable_cmdline_completion()
  else
    autocmd ddc-cmdline CmdlineLeave <buffer>
          \ if get(v:event, 'cmdlevel', 1) == 1 |
          \   call ddc#disable_cmdline_completion() |
          \ endif
  endif

  " Note: command line window must be disabled
  let s:save_cedit = &cedit
  let b:ddc_cmdline_completion = v:true
  set cedit=
endfunction
function! ddc#disable_cmdline_completion() abort
  augroup ddc-cmdline
    autocmd!
  augroup END

  if 's:save_cedit'->exists()
    let &cedit = s:save_cedit
  endif

  unlet! b:ddc_cmdline_completion

  if '#User#DDCCmdlineLeave'->exists()
    doautocmd <nomodeline> User DDCCmdlineLeave
  endif
endfunction

function! ddc#enable_terminal_completion() abort
  if !('##TextChangedT'->exists())
    return
  endif

  call ddc#enable()

  augroup ddc-terminal
    autocmd!
    autocmd TextChangedT * call ddc#_on_event('TextChangedT')
  augroup END
endfunction

function! ddc#disable() abort
  augroup ddc
    autocmd!
  augroup END
  call ddc#disable_cmdline_completion()
endfunction

function! ddc#on_complete_done(completed_item) abort
  call ddc#complete#_on_complete_done(a:completed_item)
endfunction

function! ddc#syntax_in(groups) abort
  return ddc#syntax#in(a:groups)
endfunction

function! ddc#callback(id, payload = v:null) abort
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'onCallback', [a:id, a:payload])
endfunction

function! ddc#update_items(name, items) abort
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'updateItems', [a:name, a:items])
endfunction

function! ddc#hide(event) abort
  if !ddc#_denops_running()
    return ''
  endif

  call denops#notify('ddc', 'hide', [a:event])

  return ''
endfunction

function! ddc#complete_info() abort
  return '*pum#complete_info'->exists() ?
        \ pum#complete_info() : complete_info()
endfunction

const s:root_dir = fnamemodify(expand('<sfile>'), ':h:h')
const s:sep = has('win32') ? '\' : '/'
function! ddc#_register() abort
  call denops#plugin#register('ddc',
        \ [s:root_dir, 'denops', 'ddc', 'app.ts']->join(s:sep),
        \ #{ mode: 'skip' })

  autocmd ddc User DenopsClosed call s:stopped()
endfunction

function! s:stopped() abort
  unlet! g:ddc#_initialized

  " Restore custom config
  if 'g:ddc#_customs'->exists()
    for custom in g:ddc#_customs
      call ddc#_notify(custom.method, custom.args)
    endfor
  endif
endfunction

function! ddc#_denops_running() abort
  return 'g:loaded_denops'->exists()
        \ && denops#server#status() ==# 'running'
        \ && denops#plugin#is_loaded('ddc')
endfunction

function! ddc#_on_event(event) abort
  " Note: If denops isn't running, stop
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'onEvent', [a:event])
endfunction

function! ddc#_notify(method, args) abort
  if ddc#_denops_running()
    call denops#notify('ddc', a:method, a:args)
  else
    execute printf('autocmd User DDCReady call '
          \ .. 'denops#notify("ddc", "%s", %s)', a:method, a:args->string())
  endif
endfunction
