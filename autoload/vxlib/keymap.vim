" vim:set fileencoding=utf-8 sw=3 ts=3 et
" keymap.vim - Keymaps used inside popup windows
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vxlib#keymap' )
   finish
endif
call vxlib#load#SetLoaded( '#vxlib#keymap', 1 )

" A generic handler for (modal) popup window filters with actions defined in
" `keymaps`, a list of dictionaries or functions.
"
" If an element of the list is a dictionary its elements are <key, function>
" pairs where the function accepts the parameter winid as in filter option of
" popup_create.  The function element can be of type string or funcref.
"
" If an element of the list is a function, it behaves the same as a normal
" popup filter function.  If it returns v:true, key processing is stopped and
" no futher elements form the `keymaps` list are processed.
" NOTE: this will cause problems if key-sequence disambiguation is introduced.
"
" This design enables us to compose keymaps from smaller keymaps and to
" override mappings of the default keymaps.
"
" `key_filter` always returns v:true. See implications in `popup-filter` help.
"
" TODO: the entries should contain a "Help string" or a "*help-reference*".
"
" Example:
"    let keymaps = [ {
"       \ "\<esc>" : { winid -> popup_close( winid ) },
"       \ "\<cr>" : "GlobalPopupAccept"
"       \ } ]
"    let winid = popup_dialog( s:GetBufferList(), #{
"       \ filter: { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) },
"       \ title: s:GetTitle(),
"       \ cursorline: 1,
"       \ } )
function! vxlib#keymap#key_filter( winid, key, keymaps )
   for Keymap in a:keymaps
      if type( Keymap ) == v:t_func
         " Keymap is a filter-like function. If it handles the key (returns
         " true), stop processing further keymaps.
         if Keymap( a:winid, a:key )
            break
         endif
      elseif has_key( Keymap, a:key )
         " Keymap is a dictionary and an entry for the key is present in it.
         let FilterFunc = Keymap[a:key]
         if type( FilterFunc ) == v:t_func
            call FilterFunc( a:winid )
         elseif type( FilterFunc ) == v:t_string
            exec "call " . FilterFunc . "(" . a:winid . ")"
         endif
         break
      endif
   endfor

   return v:true
endfunc

function! vxlib#keymap#down( winid )
   call win_execute( a:winid, "normal! j" )
endfunc

function! vxlib#keymap#up( winid )
   call win_execute( a:winid, "normal! k" )
endfunc

function! vxlib#keymap#page_down( winid )
   let pos = popup_getpos( a:winid )
   call win_execute( a:winid, "normal! " . pos.core_height . "j" )
endfunc

function! vxlib#keymap#page_up( winid )
   let pos = popup_getpos( a:winid )
   call win_execute( a:winid, "normal! " . pos.core_height . "k" )
endfunc

function! vxlib#keymap#scroll_left( winid )
   " call win_execute( a:winid, "normal! 0" )
   call popup_setoptions( a:winid, #{ wrap: 0 } )
endfunc

function! vxlib#keymap#scroll_right( winid )
   " call win_execute( a:winid, "normal! $" )
   " FIXME: workaround: can not scroll l/r, so we wrap to see the whole line, instead.
   call popup_setoptions( a:winid, #{ wrap: 1 } )
endfunc

