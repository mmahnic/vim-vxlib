" vim:set fileencoding=utf-8 sw=3 ts=8 et:vim
"
" Author: Marko Mahnič
" Created: April 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" Frontend for the Vim Plugin Generator
" The commands are defined in plugin/vxlib.vim

if vxlib#plugin#StopLoading('#au#vxlib#pluggen')
   finish
endif

" TODO: Each plugin can have its own dir structure. Each plugin can be configured separately.
"    1. find all autoload directories
"    2. treat every xxx/autoload directory separately
"       - process only the files in xxx/autoload
"       - if it contains vxplugins, generate code in xxx/plugin
"       - check that any of the plugins is newer than the generated file and
"       the generated file is writeable

" TODO: Analyze the use cases and change startup behaviour
"    1. The user has vxlib and uses VxRegen
"       - the /plugin files are created and used
"    2. The user has vxlib and doesn't use VxRegen
"       - the /vxlibautogen/plugin files are loaded by /plugin/vxlib.vim
"    3. The user doesn't have vxlib but uses plugins prepared with VxRegen
"       - the generator should create code that doesn't add dependencies on
"       vxlib .. code should be copied from vxlib/plugin.vim to the generated
"       files.


function! s:FindConfig(createDir)
   let locs = split(globpath(&rtp, 'plugin/vxplugin.conf'), "\n")
   if len(locs) > 0
      let plugfile = locs[0]
   else
      let locs = split(globpath(&rtp, 'plugin'), "\n")
      if len(locs) > 0
         let plugfile = locs[0] . '/vxplugin.conf'
      elseif a:createDir
         locs = split(&rtp, ',')
         if len(locs) > 0
            call mkdir(locs[0] . '/plugin')
            let plugfile = locs[0] . '/plugin/vxplugin.conf'
         else
            echoe "Can't find a place to store vxplugin.conf (eg. ~/.vim/plugin)"
            return ''
         endif
      endif
   endif
   return resolve(expand(plugfile))
endfunc

" XXX These paths are highly unreliable becaue Vim can't tell me which is
" the users primary directory for his Vim stuff.
function! vxlib#pluggen#GeneratePlugins()
   let locs = split(globpath(&rtp, 'modpython/vxlib/plugin.py'), "\n")
   if len(locs) < 1
      return
   endif
   let generator = locs[0]

   let plugfile = s:FindConfig(1)
   if bufexists(plugfile)
      let curbuf = bufnr('%')
      silent exec 'buffer ' . plugfile
      if &modified
         write
      endif
      silent exec 'buffer ' . curbuf
   endif

   if 1
      " For every autoload dir in rtp create a file in the matching plugin dir.
      " Ignore directories/files that can't be modified.
      let locs = split(globpath(&rtp, 'autoload'), "\n")
      for auloc in locs
         let plloc = fnamemodify(auloc, ":h")
         let cmd = generator . ' ' . auloc .
                  \  ' -o ' . plloc . '/plugin/_vxautogen_.vim' .
                  \  ' --update --config ' . plugfile
         exec '!python ' . cmd
      endfor
   else
      let locs = split(globpath(&rtp, 'plugin'), "\n")
      let plugins = locs[0]
      let locs = split(globpath(&rtp, 'autoload'), "\n")
      let cmd = generator . ' ' . join(locs, ' ') .
               \  ' -o ' . plugins . '/_vimuiex_autogen_.vim' .
               \  ' --update --config ' . plugins . '/vxplugin.conf'
      silent exec '!python ' . cmd
   endif
   echom 'Plugins regenerated.'
   echom 'You must restart Vim for the changes to take effect.'
endfunc

function! vxlib#pluggen#ConfigurePlugins()
   let plugfile = s:FindConfig(1)
   exec 'edit ' . plugfile
endfunc
