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
            \    parent: a:parent,
            \    onPositionChanged: []
            \    },
            \ _childs: {},
            \ _keymaps: [],
            \ _actions: {},
            \ GetParentState: funcref( 's:popup_get_parent_state' ),
            \ Show: funcref( 's:popup_show' ),
            \ Hide: funcref( 's:popup_hide' ),
            \ Close: funcref( 's:popup_close' ),
            \ }
   return l:popup
endfunc

function! vxlib#popup#Instantiate( popup, content, options )
   if !has_key( a:options, 'zindex' ) && a:popup._win.parent > 0
      let parentopts = popup_getoptions( a:popup._win.parent )
      if has_key( parentopts, 'zindex' )
         let a:options.zindex = parentopts.zindex + 1
      endif
   endif

   if has_key( a:options, 'callback' )
      let Origcallback = a:options.callback
   else
      let Origcallback = { result -> result }
   endif
   let a:options.callback = { result -> s:close_children_on_exit( a:popup, result, Origcallback ) }

   let a:options.filter = { win, key -> vxlib#keymap#key_filter( win, key, 
            \ a:popup._keymaps, a:popup._actions ) }

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
   if has_key( a:popup, '_vx_options' )
      let vx = a:popup._vx_options
      if has_key( vx, 'onpositionchanged' )
         let a:popup._win.onPositionChanged += vx.onpositionchanged
      endif
   endif
endfunc

function! vxlib#popup#ForwardKeyToParent( winid, key )
   try
      let popup = vxlib#popup#GetState( a:winid )
      let parentid = popup._win.parent
      let options = popup_getoptions( parentid )
   catch /.*/
      return
   endtry

   if has_key( options, 'filter' ) && type( options.filter ) == v:t_func
      let F = options.filter
      call F( parentid, a:key )
   endif
endfunc

function! vxlib#popup#SetText( winid, content )
   let state = popup_getpos( a:winid )
   try
      call popup_settext( a:winid, a:content )
      let newstate = popup_getpos( a:winid )

      if !empty(state) && !empty(newstate)
         if state.line != newstate.line || state.col != newstate.col
                  \ || state.width != newstate.width || state.height != newstate.height
            let popup = vxlib#popup#GetState( a:winid )
            if !empty(popup) && !empty(popup._win.onPositionChanged)
               for OnPosChanged in popup._win.onPositionChanged
                  call OnPosChanged( popup )
               endfor
            endif
         endif
      endif
   catch /.*/
   endtry
endfunc

function! s:popup_show() dict
   call popup_show( self._win.id )
endfunc

function! s:popup_hide() dict
   call popup_hide( self._win.id )
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

function! s:close_children_on_exit( popup, result, origCallback )
   if has_key( a:popup, '_childs' )
      for childname in keys(a:popup._childs)
         let child = a:popup._childs[childname]
         unlet a:popup._childs[childname]
         call vxlib#popup#Close( child )
      endfor
   endif
   let Cb = a:origCallback
   call Cb( a:result )
endfunc
