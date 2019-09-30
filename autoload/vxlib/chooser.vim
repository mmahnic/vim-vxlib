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

function! s:make_chooser_keymaps()
   return [ s:list_keymap ]
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

" Create a chooser object for choosing one or more items from a:items and
" perform operations on them.  The a:popup_options will be passed to
" popup_create().  
"
" Options filter, cursorline, hidden and wrap are ignored in a:popup_options.
" Options maxwidth and maxheight are limited by the screen size.
function! vxlib#chooser#Create( items, popup_options )
   let vx = get( a:popup_options, 'vx', {} )

   let matcher = get( vx, 'matcher', vxlib#matcher#CreateWordMatcher() )
   let matchertext = get( vx, 'matchertext', '' )
   let keymaps = get( vx, 'keymaps', [] ) + s:make_chooser_keymaps()
   let columns = s:number_or( vx, 'columns', 1 )

   " global -> displayed -> visible
   " global: all the available items; .content
   " displayed: items that match the matchertext are displayed; 
   "    indices of displayed items are in .matched
   " visible: the visible part of the list

   let chooser = vxlib#popup#Create( 'chooser', 0 )
   call vxlib#popup#Extend( chooser, #{
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
      \ SetKeymaps: funcref( 's:chooser_set_keymaps' ),
      \ SetMatcher: funcref( 's:chooser_set_matcher' ),
      \ SetMatcherText: funcref( 's:chooser_set_matcher_text' ),
      \ GetCurrentIndex: funcref( 's:chooser_get_current_index' ),
      \ SetCurrentIndex: funcref( 's:chooser_set_current_index' ),
      \ _update_displayed: funcref( 's:chooser_update_displayed' ),
      \ _displayed_to_global: funcref( 's:chooser_displayed_to_global' ),
      \ _global_to_displayed: funcref( 's:chooser_global_to_displayed' ),
      \ } )

   let current = s:number_or( vx, 'current', 0 )
   let p_options = chooser._popup_options

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

   let p_options.filter = { win, key -> vxlib#keymap#key_filter( win, key, chooser._state.keymaps ) }
   let p_options.cursorline = 1
   let p_options.hidden = 1
   let p_options.border = []
   let p_options.padding = [0, 1, 0, 1]
   let p_options.mapping = 0

   let chooser = vxlib#popup#Instantiate( chooser, "", p_options )
   call chooser._update_displayed()

   if current > 0
      call chooser.SetCurrentIndex( current )
   endif

   if chooser._state.columns > 1
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
      let colwidths = s:get_column_widths( chooser.content, chooser._state.columns, maxcolwidth )
      call win_execute( chooser._win.id, 'setlocal vartabstop=' . join( colwidths, ',' ) )
   endif

   return chooser
endfunc

" Set the keymaps that will be used in this chooser. If no keymaps are set
" the default will be used.
function! s:chooser_set_keymaps( keymaps ) dict
   let self._state.keymaps = a:keymaps
endfunc

" Set the input text for the matcher.
function! s:chooser_set_matcher_text( text ) dict
   let self._state.matchertext = a:text
   " TODO: update displayed
endfunc

" A matcher is an object that is called to narrow the list of displayed items
" to the ones that match the matcher text according to the matcher.
function! s:chooser_set_matcher( matcherObj ) dict
   let self._state.matcher = a:matcherObj
   " TODO: update displayed
endfunc

function! s:chooser_get_current_index() dict
   let curidx = line( '.', self._win.id ) - 1
   return self._displayed_to_global( curidx )
endfunc

function! s:chooser_set_current_index( itemIndex ) dict
   let index = self._global_to_displayed( a:itemIndex )
   call win_execute( self._win.id, ":" . (index + 1) )
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
      call popup_settext( self._win.id, self.content )
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
      call popup_settext( self._win.id, items )
   endif
endfunc

function! vxlib#chooser#Test()
   let chooser = vxlib#chooser#Create( ["Item A\tFirst", "Item B\tSecond", "Item C\tThird",
            \ "The last item\tFourth" ],
            \ #{ title: "Abc",
            \    vx: #{ current: 1, columns: 2 }
            \ } )
   call chooser.Show()
endfunc
