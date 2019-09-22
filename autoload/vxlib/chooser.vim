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

function! s:number_or( value, default )
   if type(a:value) != v:t_number
      return a:default
   endif
   return a:value
endfunc

function! s:list_or( value, default )
   if type(a:value) != v:t_list
      return a:default
   endif
   return a:value
endfunc


" Create a chooser object for choosing one or more items from a:items and
" perfomr operations on them.  The a:popup_options will be passed to
" popup_create().  
"
" Options filter, cursorline, hidden and wrap are ignored in a:popup_options.
" Options maxwidth and maxheight are limited by the screen size.
function! vxlib#chooser#Create( items, popup_options )

   " global -> displayed -> visible
   " global: all the available items; .content
   " displayed: items that match the matchertext are displayed; 
   "    indices of displayed items are in .matched
   " visible: the visible part of the list

   let chooser = #{
      \ _popup_options: a:popup_options,
      \ _vx_options: #{
      \    current: 0,
      \    columns: 1,
      \    keymaps: [s:list_keymap]
      \    }
      \ _state: #{
      \    matcher: vxlib#matcher#CreateWordMatcher(),
      \    matchertext: '',
      \    matched: [],
      \    }
      \ content: a:items,
      \ SetCurrent: funcref( 's:SetCurrent' ),
      \ SetColumns: funcref( 's:SetColumns' ),
      \ SetKeymaps: funcref( 's:SetKeymaps' ),
      \ AddKeymaps: funcref( 's:AddKeymaps' ),
      \ SetMatcher: funcref( 's:SetMatcher' ),
      \ SetMatcherText: funcref( 's:SetMatcherText' ),
      \ Show: funcref( 's:Show' ),
      \ _update_displayed: funcref( 's:chooser_update_displayed' ),
      \ _displayed_to_global: funcref( 's:chooser_displayed_to_global' ),
      \ _global_to_displayed: funcref( 's:chooser_global_to_displayed' ),
      \ _current_index: funcref( 's:chooser_current_index' ),
      \ }

   return chooser
endfunc

" Set the current index that will be selected the first time the chooser is
" shown.
function! s:SetCurrent( currentIndex ) dict
   let self._vx_options.current = a:currentIndex
endfunc

" Set the keymaps that will be used in this chooser. If no keymaps are set
" the default will be used.
function! s:SetKeymaps( keymaps ) dict
   let self._vx_options.keymaps = keymaps
endfunc

" Add the keymaps to the current list of keymaps that will be used in this
" chooser.  The new keymaps will be added before the existing keymaps.
function! s:AddKeymaps( keymaps ) dict
   if !has_key(self._vx_options.keymaps)
      let self._vx_options.keymaps = keymaps + [s:list_keymap]
   else
      let self._vx_options.keymaps = keymaps + self._vx_options.keymaps
   endif
endfunc

" Set the input text for the matcher.
function! s:SetMatcherText( text ) dict
   let self._state.matchertext = text " TODO: use a different name instead of vxselector
endfunc

" A matcher is an object that is called to narrow the list of displayed items
" to the ones that match the matcher text according to the matcher.
function! s:SetMatcher( matcherObj ) dict
   let self._state.matcher = matcherObj
endfunc

" Set the number of columns that will be aligned vertically.  1, 2 (TODO or 3)
" columns can be created.
function! s:SetColumns( numColumns ) dict
   let self._vx_options.columns = numColumns
endfunc

" Display the chooser.  A new popup window is created from the information
" stored in the chooser object.  The object is set as a window-local variable.
" Returns: the window id of the newly created window.
function! s:Show() dict
   " TODO: if the window self.windowid already exists and has self is a local
   " variable of that window, activate that window instead of creating a new
   " one.
   
   let current = s:number_or( self._vx_options.current, 0 )
   let columns = s:number_or( sel_vx_options.columns, 1 )
   let keymaps = s:list_or( self._vx_options.keymaps, [s:list_keymap] )
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

   let p_options.filter = { win, key -> vxlib#keymap#key_filter( win, key, keymaps ) }
   let p_options.cursorline = 1
   let p_options.hidden = 1
   let winid = popup_dialog( '', p_options )
   let self.windowid = winid
   call setwinvar( winid, s:CHOOSERVAR, self )

   call self._update_displayed()

   if current > 0
      let index = self._global_to_displayed( current )
      call self.select_item( index )
   endif

   if columns > 1
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
      let colwidths = s:get_column_widths( self.content, columns, maxcolwidth )
      call win_execute( winid, 'setlocal vartabstop=' . join( colwidths, ',' ) )
   endif

   call popup_show( winid )
   return winid
endfunc

function! s:chooser_select_item( itemIndex ) dict
   call win_execute( self.windowid, ":" . (a:itemIndex + 1) )
endfunc

function! s:chooser_current_index() dict
   let curidx = line( '.', self.windowid ) - 1
   return self._displayed_to_global( curidx )
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
   if self.matchertext == ""
      return a:globalIndex
   endif
   if len(self.matched) == 0
      return -1
   endif
   for idx in self.matched
      if idx >= a:globalIndex
         return idx
      endif
   endfor
   return self.matched[-1]
endfunc

function! s:chooser_displayed_to_global( visibleIndex ) dict
   if self.matchertext == ""
      return a:visibleIndex
   endif
   if len(self.matched) == 0 || a:visibleIndex >= len(self.matched)
      return -1
   endif
   return self.matched[a:visibleIndex]
endfunc

" Set the content of the popup list to the items that match the matchertext.
function! s:chooser_update_displayed() dict
   let items = []
   let matched = []
   let match_expr = self.matchertext
   if match_expr == ""
      let self.matched = matched
      call popup_settext( self.windowid, self.content )
   else
      call self.matcher.set_selector( match_expr )
      let idx = 0
      for it in self.content
         if self.matcher.item_matches( it )
            call add( items, it )
            call add( matched, idx )
         endif
         let idx += 1
      endfor
      let self.matched = matched
      call popup_settext( self.windowid, items )
   endif
endfunc

