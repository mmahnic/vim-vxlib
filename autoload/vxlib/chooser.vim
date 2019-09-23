" vim:set fileencoding=utf-8 sw=3 ts=3 et
" chooser.vim - Utilities for working with (filtered lists in) popup windows
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vxlib#chooser' )
   finish
endif
call vxlib#load#SetLoaded( '#vxlib#chooser', 1 )

" The name of the window varible where the chooser object is stored.
let s:CHOOSERVAR = 'vxlib_chooser'

let s:list_keymap = {
         \ 'j': { win -> vxlib#keymap#down( win ) },
         \ 'k': { win -> vxlib#keymap#up( win ) },
         \ 'h': { win -> vxlib#keymap#scroll_left( win ) },
         \ 'l': { win -> vxlib#keymap#scroll_right( win ) },
         \ 'n': { win -> vxlib#keymap#page_down( win ) },
         \ 'p': { win -> vxlib#keymap#page_up( win ) },
         \ 'f': { win -> s:popup_filter( win ) },
         \ "\<esc>" : { win -> popup_close( win ) }
         \ }

function! s:number_or( dict, name, default )
   let val = get( a:dict, a:name, a:default )
   if type(val) != v:t_number
      return a:default
   endif
   return val
endfunc

function! s:list_or( dict, name, default )
   let val = get( a:dict, a:name, a:default )
   if type(val) != v:t_list
      return a:default
   endif
   return val
endfunc

function! s:make_list_keymap()
   return s:list_keymap
   " TODO: prepare the keymap from user settings:
   " call vxlib#chooser#SetDefaultKeys = #{
   "    up: [ 'k', "\<up>" ], down: [ 'j', "\<down>" ],
   "    pageUp: [ 'p', "\<pageup>" ], pageDown: [ 'n', "\<pagedown>" ],
   "    home: [ "\<home>" ]
   "    }
   " call vxlib#chooser#SetDefaultActions = #{
   "    up: { win -> vxlib#keymap#up( win ) }
   "    }
endfunc

" Get a chooser object from the window a:windowid.  Returns 0 if the window or
" the variable does not exist.
function! vxlib#chooser#GetWinVar( windowid )
   let chooser = getwinvar( a:windowid, s:CHOOSERVAR )
   if type( chooser ) != v:t_dict
      return 0
   endif
   return chooser
endfunc

" Create a chooser object for choosing one or more items from a:items and
" perfomr operations on them.  The a:popup_options will be passed to
" popup_create().  
"
" Options filter, cursorline, hidden and wrap are ignored in a:popup_options.
" Options maxwidth and maxheight are limited by the screen size.
function! vxlib#chooser#Create( items, popup_options )
   let vx = get( a:popup_options, 'vx', {} )

   let matcher = get( vx, 'matcher', vxlib#matcher#CreateWordMatcher() )
   let matchertext = get( vx, 'matchertext', '' )
   let keymaps = get( vx, 'keymaps', [] ) + [s:make_list_keymap()]
   let columns = s:number_or( vx, 'columns', 1 )

   " global -> displayed -> visible
   " global: all the available items; .content
   " displayed: items that match the matchertext are displayed; 
   "    indices of displayed items are in .matched
   " visible: the visible part of the list

   let chooser = #{
      \ _popup_options: a:popup_options,
      \ _vx_options: vx,
      \ _state: #{
      \    keymaps: keymaps,
      \    columns: columns,
      \    matcher: matcher,
      \    matchertext: matchertext,
      \    matched: []
      \    },
      \ content: a:items,
      \ SetKeymaps: funcref( 's:SetKeymaps' ),
      \ SetMatcher: funcref( 's:SetMatcher' ),
      \ SetMatcherText: funcref( 's:SetMatcherText' ),
      \ GetCurrentIndex: funcref( 's:GetCurrentIndex' ),
      \ SetCurrentIndex: funcref( 's:SetCurrentIndex' ),
      \ Show: funcref( 's:Show' ),
      \ Close: funcref( 's:Close' ),
      \ _update_displayed: funcref( 's:chooser_update_displayed' ),
      \ _displayed_to_global: funcref( 's:chooser_displayed_to_global' ),
      \ _global_to_displayed: funcref( 's:chooser_global_to_displayed' ),
      \ }

   return chooser
endfunc

" Set the keymaps that will be used in this chooser. If no keymaps are set
" the default will be used.
function! s:SetKeymaps( keymaps ) dict
   let self._state.keymaps = a:keymaps
endfunc

" Set the input text for the matcher.
function! s:SetMatcherText( text ) dict
   let self._state.matchertext = a:text
   " TODO: update displayed
endfunc

" A matcher is an object that is called to narrow the list of displayed items
" to the ones that match the matcher text according to the matcher.
function! s:SetMatcher( matcherObj ) dict
   let self._state.matcher = a:matcherObj
   " TODO: update displayed
endfunc

function! s:GetCurrentIndex() dict
   let curidx = line( '.', self.windowid ) - 1
   return self._displayed_to_global( curidx )
endfunc

function! s:SetCurrentIndex( itemIndex ) dict
   let index = self._global_to_displayed( a:itemIndex )
   call win_execute( self.windowid, ":" . (index + 1) )
endfunc


" Display the chooser.  A new popup window is created from the information
" stored in the chooser object.  The object is set as a window-local variable.
" Returns: the window id of the newly created window.
function! s:Show() dict
   " TODO: if the window self.windowid already exists and self is also a local
   " variable of that window, activate that window instead of creating a new
   " one.
   
   let vx = self._vx_options
   let current = s:number_or( vx, 'current', 0 )
   let p_options = self._popup_options

   let maxwidth = &columns - 6
   if has_key( p_options, 'maxwidth' ) && p_options.maxwidth < maxwidth
      let maxwidth = p_options.maxwidth
   endif
   let p_options.maxwidth = maxwidth

   let maxheight = &lines - 6
   if has_key( p_options, 'maxheight' ) && p_options.maxheight < maxheight
      let maxheight = p_options.maxheight
   endif
   let p_options.maxheight = maxheight

   let p_options.wrap = 0

   let p_options.filter = { win, key -> vxlib#keymap#key_filter( win, key, self._state.keymaps ) }
   let p_options.cursorline = 1
   let p_options.hidden = 1
   let winid = popup_dialog( '', p_options )
   let self.windowid = winid
   call setwinvar( winid, s:CHOOSERVAR, self )

   call self._update_displayed()

   if current > 0
      call self.SetCurrentIndex( current )
   endif

   if self._state.columns > 1
      " The actual width of the window depends on the visible items and its
      " use is unreliable for limiting the column width. We depend on maxwidth
      " and &columns, instead.
      if has_key(p_options, 'maxwidth')
         let maxcolwidth = p_options.maxwidth / 3
      else
         let maxcolwidth = &columns / 3
      endif
      if maxcolwidth < 8
         let maxcolwidth = 8
      endif
      let colwidths = s:get_column_widths( self.content, self._state.columns, maxcolwidth )
      call win_execute( winid, 'setlocal vartabstop=' . join( colwidths, ',' ) )
   endif

   call popup_show( winid )
   return winid
endfunc

function! s:Close() dict
   call popup_close( self.windowid )
   " TODO: close all child windows
endfunc

function! s:get_column_widths( items, numcols, maxwidth )
   let maxw = 6
   for it in a:items
      " TODO: add support for more columns
      let pos = stridx( it, "\t" )
      if pos > maxw
         let maxw = pos
         if maxw >= a:maxwidth
            let maxw = a:maxwidth
            break
         endif
      endif
   endfor
   return [maxw + 2, 2]
endfunc

function! s:chooser_global_to_displayed( globalIndex ) dict
   if self._state.matchertext == ""
      return a:globalIndex
   endif
   if len(self._state.matched) == 0
      return -1
   endif
   for idx in self._state.matched
      if idx >= a:globalIndex
         return idx
      endif
   endfor
   return self._state.matched[-1]
endfunc

function! s:chooser_displayed_to_global( visibleIndex ) dict
   if self._state.matchertext == ""
      return a:visibleIndex
   endif
   if len(self._state.matched) == 0 || a:visibleIndex >= len(self._state.matched)
      return -1
   endif
   return self._state.matched[a:visibleIndex]
endfunc

" Set the content of the popup list to the items that match the matchertext.
function! s:chooser_update_displayed() dict
   let items = []
   let matched = []
   let match_expr = self._state.matchertext
   if match_expr == ""
      let self._state.matched = matched
      call popup_settext( self.windowid, self.content )
   else
      call self._state.matcher.set_selector( match_expr )
      let idx = 0
      for it in self.content
         if self._state.matcher.item_matches( it )
            call add( items, it )
            call add( matched, idx )
         endif
         let idx += 1
      endfor
      let self._state.matched = matched
      call popup_settext( self.windowid, items )
   endif
endfunc

function! vxlib#chooser#Test()
   let chooser = vxlib#chooser#Create( ["Item A", "Item B", "Item C"], 
            \ #{ title: "Abc",
            \    vx: #{ current: 1, columns: 1 }
            \ } )
   call chooser.Show()
endfunc
