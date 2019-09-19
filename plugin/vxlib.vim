if vxlib#load#IsLoaded( 'vxlib' )
   finish
endif
call vxlib#load#SetLoaded( 'vxlib', 1 )
