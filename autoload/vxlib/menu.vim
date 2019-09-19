" vim:set fileencoding=utf-8 sw=3 ts=8 et:vim
" menu.vim - select a backend to display a (popup) menu
"
" Author: Marko Mahnič
" Created: May 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vxlib#menu' )
   finish
endif
call vxlib#load#SetLoaded( '#vxlib#menu', 1 )

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
let s:has_vxtextmenu = exists('*vimuiex#vxtextmenu#VxTextMenu')
   \ || vxlib#plugin#PluginExists('vimuiex#vxtextmenu', 'autoload/vimuiex/vxtextmenu.vim')
let s:has_tlibinput = exists('g:loaded_tlib')
   \ || vxlib#plugin#PluginExists('tlib', 'autoload/tlib.vim')

" supported modes: vimuiex, popup, choice
" (Is it possible to use :emenu here? it seems that I need to map-<expr>, so NO)
let s:BackendOrder = ['popuplist', 'vimuiex', 'tlib', 'popup', 'choice'] " 'emenu'
" =========================================================================== 

function! s:CheckExtraSettings()
   if exists('g:vxlib_menu_backend_order') 
      if !empty(g:vxlib_menu_backend_order)
         let neworder = copy(g:vxlib_menu_backend_order)
         for mm in s:BackendOrder
            if index(neworder, mm) >= 0
               continue
            endif
            call add(neworder, mm)
         endfor
         let s:BackendOrder = neworder
      endif
      unlet g:vxlib_menu_backend_order
   endif
endfunc

function! s:FindGoodBackend(backend, cando, order)
   if !a:cando[a:backend]
      let newback = ''
      for mm in a:order
         if a:cando[mm]
            return mm
         endif
      endfor
      if newback == ''
         echoe "None of the configured backends is available. BackendOrder:"
         echo a:order
         return ''
      endif
   endif
   return a:backend
endfunc

" requires: +menu
function! vxlib#menu#DoVimMenu(menuPath, backend)
   call s:CheckExtraSettings()
   let mback = a:backend
   if index(s:BackendOrder, mback) < 0 | let mback = s:BackendOrder[0] | endif
   let vimmode = 'n' " TODO vimmode as parameter
   let name = a:menuPath

   let cando = {}
   let cando[mback] = 0
   let cando['popuplist'] = has('popuplist') && has('menu')
   let cando['vimuiex'] = s:has_vxtextmenu && has('menu') && has('python') 
            \ && (!has('gui_running') || has('python_screen'))
   let cando['popup'] = has('menu') && has('gui_running')
   let cando['tlib'] = 0
   " let cando['emenu'] = has('menu')
   let cando['choice'] = has('menu') 

   let mback = s:FindGoodBackend(mback, cando, s:BackendOrder)

   if mback == ''
      return
   elseif mback == 'popuplist'
      call popuplist(vimmode . 'menu', name, { 'mode': 'shortcut' } )
   elseif mback == 'vimuiex'
      call vimuiex#vxtextmenu#VxTextMenu(name, vimmode)
      " exec vimmode . 'unmenu ' . name
   elseif mback == 'popup'
      exec 'popup ' . name
   "elseif mback == 'emenu'
   "   if !exists("did_install_default_menus") || !did_install_default_menus
   "      source $VIMRUNTIME/menu.vim
   "   endif
   "   exec 'norm :emenu ' . name
   elseif mback == 'choice'
      call s:ChoiceVimMenu([name], vimmode)
   endif
endfunc

" TODO: define the structure for items
function! vxlib#menu#DoMenu(items, backend)
   call s:CheckExtraSettings()
   let mback = a:backend
   if !index(s:BackendOrder, mback) < 0 | let mback = s:BackendOrder[0] | endif

   let cando = {}
   let cando[mback] = 0
   let cando['vimuiex'] = s:has_vxtextmenu && has('python')
            \ && (!has('gui_running') || has('python_screen'))
   let cando['tlib'] = s:has_tlibinput
   let cando['popup'] = 0
   " let cando['emenu'] = 0
   let cando['choice'] = 1
   
   " TODO: parse items and display the menu
   echoe "DoMenu not implemented. Try DoVimMenu."
endfunc

function! vxlib#menu#GetMenuTitles(menuPath, vimmode)
   if type(a:menuPath) == type([])
      if len(a:menuPath) > 0 && a:menuPath[0] == ''
         let menuPath = join(map(copy(a:menuPath[1:]), 'escape(v:val," .")'), '.')
      else
         let menuPath = join(map(copy(a:menuPath), 'escape(v:val," .")'), '.')
      endif
   else
      let menuPath = a:menuPath
   endif
   " select the correct menu depending on current mode
   let lmns = vxlib#cmd#Capture(a:vimmode . 'menu ' . menuPath, 1)
   let themenu = []
   for line in lmns
      let text = ''
      let cmd = ''
      let mtitle = matchstr(line, '^\s*\d\+\s.\+') | " space digit space any
      if mtitle != ''
         let mtitle=substitute(mtitle, '^\(\s*\)\d\+\s\(.\+\)$', "\\1|\\2", '')
         call add(themenu, mtitle)
      endif
   endfor
   unlet lmns
   return themenu
endfunc

function! s:ChoiceVimMenu(menuPathList, mode)
   let menuPath = a:menuPathList
   let allSubmenus = vxlib#menu#GetMenuTitles(menuPath, a:mode)
   if !(len(menuPath) == 1 && menuPath[0] == '')
      let allSubmenus = allSubmenus[1:]
   endif
   if len(allSubmenus) < 1
      let curlevel = 0
   else
      let curlevel = len(matchstr(allSubmenus[0], '^\s*'))
   endif
   let pos = 0
   let choices = []
   for i in range(len(allSubmenus))
      let item = allSubmenus[i]
      let level = len(matchstr(item, '^\s*'))
      if level != curlevel
         continue
      endif
      let item = split(matchstr(item, '\s*|\zs.*'), '\^I')[0]
      if item =~ '^-SEP'
         call add(choices, ['', '-', 0])
      else
         let pos += 1
         let qc = '' . pos
         let nextlevel = level
         if  i < len(allSubmenus) - 1
            let nextlevel = len(matchstr(allSubmenus[i+1], '^\s*'))
         endif
         if nextlevel > level | let subm = 1
         else | let subm = 0
         endif
         call add(choices, [qc, item, subm])
      endif
   endfor

   if len(choices) < 1
      if len(menuPath) > 1 | return 0
      else | return -1
      endif
   endif

   unlet item
   let mdisp = ['    [Menu: ' . join(menuPath, '.') . ']' ]
   let maxItems = &lines-1
   if len(menuPath) > 1
      let maxItems -= 1
   endif
   let k = 0
   let ikmap = {} " display-index -> item-index
   for item in choices
      let k += 1
      if item[1] == '-' | continue
      else
         let i = len(mdisp)
         let str = printf('%2d. %s', i, substitute(item[1], '&', '', 'g'))
         if item[2] | let str = str . ' >>>' | endif
         call add(mdisp, str)
         let ikmap[i] = k-1
      endif
      if len(mdisp) >= maxItems | break | endif
   endfor
   if len(menuPath) > 1
      call add(mdisp, '99. (Go Up)')
   endif

   while 1
      let sel = inputlist(mdisp)
      if sel == 0 | return -1 | endif " Cancelled
      let nsel = 0 + sel
      if nsel == 99 || (nsel == len(mdisp)-1 && mdisp[-1] =~ '^99. ') " Go Up or Cancel
         if len(menuPath) > 1 | return 0
         else | return -1
         endif
      endif
      let selected = []
      if has_key(ikmap, nsel)
         let nsel = ikmap[nsel]
         let selected = choices[nsel]
      endif
      if len(selected) < 1
         echoe "Invalid menu choice " . nsel
         return -1
      endif
      let newPath = copy(menuPath)
      call add(newPath, selected[1])
      if selected[2] " submenu
         redraw!
         let nsel = s:ChoiceVimMenu(newPath, a:mode)
         if nsel == 0 | redraw! | endif
         if nsel < 0 | break | endif
      else
         if newPath[0] == '' | let newPath = newPath[1:] | endif
         let selmenu = join(map(newPath, 'escape(v:val," .")'), '.')
         " TODO: execute in the right mode
         exec 'emenu ' . selmenu
         break
      endif
   endwhile
   return -1
endfunc

" @param mode Same as in tlib#input#List (m/s, 0/i)
function! vxlib#menu#DoChoice(mode, title, items, backend)
   call s:CheckExtraSettings()
   let mback = a:backend
   if !index(s:BackendOrder, mback) < 0 | let mback = s:BackendOrder[0] | endif

   let cando = {}
   let cando[mback] = 0
   let cando['vimuiex'] = s:has_vxtextmenu && has('python')
            \ && (!has('gui_running') || has('python_screen'))
   let cando['vimuiex'] = 0
   let cando['tlib'] = s:has_tlibinput
   let cando['popup'] = 0
   let cando['choice'] = 1

   let mback = s:FindGoodBackend(mback, cando, s:BackendOrder)

   if mback == ''
      return ''
   elseif mback == 'vimuiex'
      " TODO: call vimuiex#vxlist#VxPopup(...)
      return ''
   elseif mback == 'tlib'
      return tlib#input#List(a:mode, a:title, a:items)
   elseif mback == 'choice'
      return s:InputList(a:mode, a:title, a:items)
   endif
endfunc

function! s:InputList(mode, title, items)
   if len(a:mode) > 0 | let mode = a:mode[0]
   else | let mode = 's' | endif
   if len(a:mode) > 1 | let type = a:mode[1]
   else | let type = '' | endif

   if mode == 'm' | let nothing = []
   elseif type == 'i' | let nothing = 0
   else | let nothing = ''
   endif

   let mdisp = [a:title]
   let k = 0
   let ikmap = {}
   for item in a:items
      let k += 1
      if item =~ '^\s*-\+\s*$' | continue
      else
         let i = len(mdisp)
         let str = printf('%2d. %s', i, substitute(item, '&', '', 'g'))
         call add(mdisp, str)
         let ikmap[i] = k-1
      endif
      if len(mdisp) >= &lines-1 | break | endif
   endfor

   let sel = inputlist(mdisp)
   if sel == 0
      return nothing
   endif
   let nsel = 0 + sel
   if has_key(ikmap, nsel)
      let nsel = ikmap[nsel]
   else
      return nothing
   endif

   if mode == 'm'
      if type == 'i' | return [nsel+1]
      else | return [a:items[nsel]]
      endif
   else
      if type == 'i' | return nsel+1
      else | return a:items[nsel]
      endif
   endif
endfunc

function! vxlib#menu#TestVimMenu(backend)
   call vxlib#menu#DoVimMenu("", a:backend)
endfunc

function! vxlib#menu#TestChoice(backend)
   let items = [ "Item A", "Item B", "Item C", "Last Item" ]
   let res1 = vxlib#menu#DoChoice("m", "Test M", items, a:backend)
   echo " "
   let res2 = vxlib#menu#DoChoice("s", "Test S", items, a:backend)
   echo " "
   let res3 = vxlib#menu#DoChoice("mi", "Test MI", items, a:backend)
   echo " "
   let res4 = vxlib#menu#DoChoice("si", "Test SI", items, a:backend)
   echo " "
   echo "Selected:"
   echo res1
   echo res2
   echo res3
   echo res4
endfunc

