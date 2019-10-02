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
" @p `keymaps`, a list of dictionaries or functions.
"
" If an element of the list is a dictionary its elements are <key, function>
" pairs where the function accepts the parameter winid as in filter option of
" popup_create.  The function element can be of type string or funcref.
"
" TODO: maybe all the functions should accept win + key (now this is done only
" for actions; functions for other types of mappings accept only win).
"
" If an element of the list is a function, it behaves the same as a normal
" popup filter function.  If it returns v:true, key processing is stopped and
" no futher elements form the `keymaps` list are processed.
" NOTE: this will cause problems if key-sequence disambiguation is introduced.
"
" This design enables us to compose keymaps from smaller keymaps and to
" override mappings of the default keymaps.
"
" @p `actions` is a dictionary where the values are callables that accept
" parameters win and key.
"
" `key_filter` always returns v:true. See implications in `popup-filter` help.
"
" TODO: the entries should contain a "Help string" or a "*help-reference*".
"
" Example:
"    let actions = #{
"       \ close: { win, key -> popup_close( win ) }
"       \ }
"    let keymaps = [ {
"       \ "\<esc>" : 'close',                           " action
"       \ "\<cr>" : '*GlobalPopupAccept',               " global function
"       \ 'x' : { win -> s:do_something_with( win ) }   " lambda
"       \ } ]
"    let winid = popup_dialog( s:GetBufferList(), #{
"       \ filter: { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps, actions ) },
"       \ title: s:GetTitle(),
"       \ cursorline: 1,
"       \ } )
function! vxlib#keymap#key_filter( winid, key, keymaps, actions )
   for Keymap in a:keymaps
      if type( Keymap ) == v:t_func
         " Keymap is a filter-like function. If it handles the key (returns
         " true), stop processing further keymaps.
         if Keymap( a:winid, a:key )
            return v:true
         endif
      elseif has_key( Keymap, a:key )
         " Keymap is a dictionary and an entry for the key is present in it.
         let FilterFunc = Keymap[a:key]
         if type( FilterFunc ) == v:t_func
            " call popup_notification( 'Funcref: ' . FilterFunc, #{ time: 500 } )
            call FilterFunc( a:winid )
            return v:true
         elseif type( FilterFunc ) == v:t_string
            if FilterFunc[:0] == '*'
               if exists( FilterFunc )
                  " call popup_notification( 'Funcname: ' . FilterFunc, #{ time: 500 } )
                  exec "call " . FilterFunc[1:] . "(" . a:winid . ")"
                  return v:true
               endif
            elseif has_key( a:actions, FilterFunc )
               " call popup_notification( 'Action: ' . FilterFunc, #{ time: 500 } )
               let ActionFunc = a:actions[FilterFunc]
               call ActionFunc( a:winid, a:key )
               return v:true
            endif
            " call popup_notification( 'Unknown action: ' . FilterFunc, #{ time: 500 } )
            return v:true
         endif
         " call popup_notification( 'Unsupported action type for key ' . a:key, #{ time: 500 } )
         return v:true
      endif
   endfor

   " call popup_notification( 'Unhandled key: ' . a:key, #{ time: 500 } )
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

