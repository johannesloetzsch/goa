##
# Add include search path whenever using the given 'api'
#
# \param api   API for which the input-search path must be extended
# \param args  include-search path elements relative to the API archive
#
proc append_include_dir_for_api { api args } {

	if {[using_api $api]} {
		global include_dirs
		lappend include_dirs [file join [api_archive_dir $api] {*}$args]
	}
}

# C runtime

append_include_dir_for_api libc  include libc
append_include_dir_for_api libc  include libc-genode

if {$arch == "x86_64"} {
	append_include_dir_for_api libc  include spec x86    libc
	append_include_dir_for_api libc  include spec x86_64 libc
}

if {$arch == "arm_v8a"} {
	append_include_dir_for_api libc  include spec arm_64 libc
}

if {[using_api libc]} {

	# trigger include of 'sys/signal.h' to make NSIG visible
	lappend cppflags "-D__BSD_VISIBLE"
	# prevent gcc headers from defining __size_t
	lappend cppflags "-D__FreeBSD__=8"
}

if {[using_api compat-libc]} {

	set compat_libc_dir [file join [api_archive_dir compat-libc] src lib compat-libc]

	lappend lib_src [file join $compat_libc_dir compat.cc]
}

# Standard C++ library

append_include_dir_for_api stdcxx  include stdcxx
append_include_dir_for_api stdcxx  include stdcxx std
append_include_dir_for_api stdcxx  include stdcxx c_global

if {$arch == "x86_64"}  { append_include_dir_for_api stdcxx  include spec x86_64 stdcxx }
if {$arch == "arm_v8a"} { append_include_dir_for_api stdcxx  include spec arm_64 stdcxx }

# SDL

append_include_dir_for_api sdl        include SDL
append_include_dir_for_api sdl_image  include SDL

if {[using_api sdl]} {

	# CMake's detection of libSDL expects the library named uppercase
	set symlink_name [file join $abi_dir SDL.lib.so]
	if {![file exists $symlink_name]} {
		file link -symbolic $symlink_name "sdl.lib.so" }

	set sdl_include_dir [file join [api_archive_dir sdl] include SDL]

	# bring CMake on the right track to find the headers and library
	lappend cmake_quirk_args "-DSDL_INCLUDE_DIR=$sdl_include_dir"
	lappend cmake_quirk_args "-DCMAKE_SYSTEM_LIBRARY_PATH='$abi_dir'"
	lappend cmake_quirk_args "-DSDL_LIBRARY:STRING=':sdl.lib.so'"
}

# Curl

if {$arch == "x86_64"} {
	append_include_dir_for_api curl  src lib curl spec 64bit curl
}

# Genode's posix library

if {[using_api posix]} {

	#
	# Genode's fork mechanism relies on a specific order of the linked
	# shared libraries libc, vfs, libm, and posix. Since the order of apis
	# listed in the 'used_apis' file can be arbitrary, we ensure the
	# link oder by reordering 'ldlibs_exe'.
	#

	# remove critical entries
	foreach lib [list libc libm posix] {
		set idx [lsearch -exact $ldlibs_exe "-l:$lib.lib.so"]
		if {$idx != -1} { set ldlibs_exe [lreplace $ldlibs_exe $idx $idx] }
	}

	# prepend known-good link order of the critical libaries
    set ldlibs_exe [linsert $ldlibs_exe 0 "-l:libc.lib.so" "-l:libm.lib.so" "-l:posix.lib.so"]
}

# Genode's blit library

if {[using_api blit]} {

	set blit_dir [file join [api_archive_dir blit] src lib blit]

	if {$arch == "x86_64"} {
		lappend include_dirs [file join $blit_dir spec x86]
		lappend include_dirs [file join $blit_dir spec x86_64]
	}
	if {$arch == "arm_v8a"} {
		lappend include_dirs [file join $blit_dir spec arm_64]
	}

	lappend lib_src [file join $blit_dir blit.cc]
}

if {[using_api gui_session]} {

	# prevent strict-aliasing errors in gui_session.h
	lappend cxxflags -fno-strict-aliasing
}

