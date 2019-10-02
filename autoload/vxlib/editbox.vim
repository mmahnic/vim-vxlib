" vim:set fileencoding=utf-8 sw=3 ts=3 et
" editbox.vim - A popup window for editing a line of text
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vimuiex#editbox' )
   finish
endif
call vxlib#load#SetLoaded( '#vimuiex#editbox', 1 )

let s:WT_EDITBOX = 'editbox'

"let s:editbox_keymap = {
"         \ "\<esc>" : { win -> popup_close( win ) },
"         \ "\<tab>" : { win -> popup_close( win ) },
"         \ "\<backspace>" : { win -> s:editboxwin_remove_char( win ) },
"         \ "\<cr>" : { win -> s:editboxwin_forward_key_to_parent( win, "\<cr>" ) }
"         \ }
let s:editbox_keymap = {
         \ "\<backspace>" : { win -> s:editboxwin_remove_char( win ) },
         \ }

function! s:make_editbox_keymaps()
   let keymaps = [s:editbox_keymap, { win, key -> s:editboxwin_append_char( win, key ) }]
   return keymaps
   " TODO: prepare the keymap from user settings:
   " call vxlib#editbox#SetDefaultKeys = #{
   "    up: [ 'k', "\<up>" ], down: [ 'j', "\<down>" ],
   "    pageUp: [ 'p', "\<pageup>" ], pageDown: [ 'n', "\<pagedown>" ],
   "    home: [ "\<home>" ]
   "    }
   " call vxlib#chooser#SetDefaultActions = #{
   "    up: { win -> vxlib#keymap#up( win ) }
   "    }
endfunc

" @p parent is the parent popup window (window-id)
function! vxlib#editbox#Create( content, popup_options, parent )
   let vx = get( a:popup_options, 'vx', {} )
   let keymaps = get( vx, 'keymaps', [] ) + s:make_editbox_keymaps()

   " Emitted when self.text changes. handler( editbox, text ).
   let onTextChanged = get( vx, 'ontextchanged', [] )

   let editbox = vxlib#popup#Create( s:WT_EDITBOX, a:parent )
   call vxlib#popup#Extend( editbox, #{
      \ _popup_options: a:popup_options,
      \ _vx_options: vx,
      \ _state: #{
      \    onTextChanged: onTextChanged,
      \    text: a:content,
      \    },
      \ _keymaps: keymaps,
      \ MoveWindow: funcref( 's:editbox_move_window' ),
      \ } )

   let p_options = editbox._popup_options
   let p_options.wrap = 0
   let p_options.drag = 0
   let p_options.height = 1
   let p_options.cursorline = 0
   let p_options.hidden = 1
   let p_options.mapping = 0

   let width = get( p_options, 'width', 0 )
   if width < 1
      let width = get( p_options, 'minwidth', 0 )
   endif
   if width < 1
      let width = get( p_options, 'maxwidth', 0 )
   endif
   if width < 1
      let width = strchars( self._state.text )
   endif
   if width < 1
      let width = 40
   endif

   let p_options.width = width
   let p_options.minwidth = width
   let p_options.maxwidth = width

   return vxlib#popup#Instantiate( editbox, editbox._state.text, p_options )
endfunc

function! s:editbox_move_window( left, top, width, height ) dict
   call popup_move( self._win.id #{ 
            \ line: top,
            \ col: left,
            \ height: 1,
            \ width: width
            \ })
endfunc

function! s:editbox_emit_text_changed( editbox )
   for HandleChanged in a:editbox._state.onTextChanged
      call HandleChanged( a:editbox, a:editbox._state.text )
   endfor
endfunc

function! s:editboxwin_append_char( winid, key )
   " TODO: is it safe to assume that special key sequences start with 0x80?
   if a:key < " " || a:key[0] == "\x80"
      return
   endif
   let editbox = vxlib#popup#GetState( a:winid )
   if empty(editbox)
      return
   endif

   let editbox._state.text .= a:key
   call popup_settext( editbox._win.id, editbox._state.text )
   call s:editbox_emit_text_changed( editbox )
endfunc

function! s:editboxwin_remove_char( winid )
   let editbox = vxlib#popup#GetState( a:winid )
   if empty(editbox)
      return
   endif

   let textlen = strchars(editbox._state.text)
   if textlen > 0
      let editbox._state.text = strcharpart( editbox._state.text, 0, textlen - 1 )
      call popup_settext( editbox._win.id, editbox._state.text )
      call s:editbox_emit_text_changed( editbox )
   endif
endfunc

function! vxlib#editbox#Test()
   let editbox = vxlib#editbox#Create( 'Test',
            \ #{ width: 40,
            \    minwidth: 40,
            \    vx: #{}
            \ },
            \ 0 )
   call editbox.Show()
endfunc
