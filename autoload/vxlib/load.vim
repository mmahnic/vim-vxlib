" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" A registry of autoloaded files. Ids of autoloaded files start with '#' when
" calling vxlib#load#IsLoaded and vxlib#load#SetLoaded.
let g:loadedAutoload = get(g:, 'loadedAutoload', {})
if get(g:loadedAutoload, '#vxlib#load', 0)
   finish
endif

" A registry of loaded plugins.
let g:loadedPlugins = get(g:, 'loadedPlugins', {})

" Return true if the plugin was loaded.
function! vxlib#load#IsLoaded( idPlugin )
   if a:idPlugin[:0] == '#'
      return get(g:loadedAutoload, a:idPlugin, 0)
   endif
   return get(g:loadedPlugins, a:idPlugin, 0)
endfunc

" Mark the plugin as loaded by storing its version
function! vxlib#load#SetLoaded( idPlugin, version )
   if a:idPlugin[:0] == '#'
      let g:loadedAutoload[a:idPlugin] = a:version
   else
      let g:loadedPlugins[a:idPlugin] = a:version
   endif
endfunc

call vxlib#load#SetLoaded( '#vxlib#load', 1 )
