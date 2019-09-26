" vim:set fileencoding=utf-8 sw=3 ts=3 et
" popup.vim - A base class for vxlib windows
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" The name of the window varible where the editbox object is stored.
let s:POPUVAR = "vxlib_popup"

function! vxlib#popup#GetState( winid )
   return getwinvar( a:winid, s:POPUVAR, {} )
endfunc

function! vxlib#popup#Create(type, parent)
   let l:popup = #{
            \ _win: #{
            \    id: -1,
            \    type: a:type,
            \    parent: a:parent 
            \    },
            \ GetParentState: funcref( 's:popup_get_parent_state' ),
            \ Show: funcref( 's:popup_show' ),
            \ Close: funcref( 's:popup_close' ),
            \ }
   return l:popup
endfunc

function! vxlib#popup#Instantiate( popup, content, options )
   let winid = popup_create( a:content, a:options )
   let a:popup._win.id = winid
   call setwinvar( winid, s:POPUVAR, a:popup )
   return a:popup
endfunc

" Popup is vxlib_popup window variable or popup window id
function! vxlib#popup#Close( popup_or_id )
   if type( a:popup_or_id ) == v:t_dict
      let popup = a:popup_or_id
      if has_key( popup, '_win' )
         call popup_close( popup._win.id )
         let popup._win.id = -1
      endif
   elseif type( a:popup_or_id ) == v:t_number
      let id = a:popup_or_id
      let popup = vxlib#popup#GetState( id )
      call popup_close( id )
      if has_key( popup, '_win' )
         let popup._win.id = -1
      endif
   endif
endfunc

" A one-level inheritance mechanism.
function! vxlib#popup#Extend(popup, extra)
   for name in keys( a:extra )
      if name == '_win'
         continue
      endif
      let a:popup[name] = a:extra[name]
   endfor
endfunc

function! s:popup_show() dict
   call popup_show( self._win.id )
endfunc

function! s:popup_get_parent_state() dict
   if !has_key( self, '_win' ) || !has_key( self._win, 'parent' )
      return {}
   endif

   let parentState = vxlib#popup#GetState( self._win.parent )
   if type( parnetState ) != v:t_dict
      return {}
   endif

   return parentState
endfunc

function! s:popup_close() dict
   call vxlib#popup#Close( self )
endfunc
