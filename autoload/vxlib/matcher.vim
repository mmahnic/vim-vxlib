" vim:set fileencoding=utf-8 sw=3 ts=3 et
" matcher.vim - Filtering of items from a chooser for display.
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" The Matcher interface:
"  - set_selector( text ) 
"       Set the text condition that will be used by the matcher.  The
"       condition is usually preprocessed by the matcher for faster matching.
"
"  - item_matches( item_display_text ) 
"       Returns true if the item's display text matches the condition that was
"       previously set on the matcher.


" A matcher that matches the words defined by the selector.
" None of the words with '-' prefix must be found.
" All words with '+' prefix and words without prefix must be found.
" To find the word '-' use '+-'.
function! vxlib#matcher#CreateWordMatcher()
   " words: pairs [ word, 1/0 ]; '-w' -> ['w', 0], '+w' -> ['w', 1], ohter -> ['w', 1]
   " pluscount: number of required words (second element is 1)
   let matcher = #{ words: [], pluscount: 0 }

   function! matcher.set_selector( selector )
      let parts = split( a:selector, '\s\+')
      let words = []
      for wrd in parts
         if wrd[0] == '-'
            if len(wrd) > 1
               call add( words, [wrd[1:], 0] )
            endif
         elseif wrd[0] == '+'
            if len(wrd) > 1
               call add( words, [wrd[1:], 1] )
            endif
         else
            call add( words, [wrd, 1] )
         endif
      endfor
      let self.words = words
      let self.pluscount = 0
      for wrd in self.words
         if wrd[1] > 0
            let self.pluscount += 1
         endif
      endfor
   endfunc

   function! matcher.item_matches( text )
      let pluscount = 0
      for wrd_on in self.words
         if stridx( a:text, wrd_on[0] ) >= 0
            if wrd_on[1] < 1
               return v:false
            endif
            let pluscount += 1
         endif
      endfor
      return pluscount == self.pluscount
   endfunc

   return matcher
endfunc
