
if exists('g:vxlib_exception_list')
   if len(g:vxlib_exception_list)
      for err in g:vxlib_exception_list
         echom err
      endfor
   endif
   unlet g:vxlib_exception_list
endif
