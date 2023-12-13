cmake_minimum_required(VERSION 3.19) # because of json

function(port_dependencies_internal)
	message("Executing vcpkg depend_info")
	execute_process(COMMAND ${CMAKE_SOURCE_DIR}/vcpkg/vcpkg depend-info --overlay-ports=${CMAKE_SOURCE_DIR}/ports --format=list --sort=reverse docwire OUTPUT_VARIABLE depend_info ERROR_VARIABLE stderr_content COMMAND_ECHO STDOUT)
	if(NOT stderr_content STREQUAL "")
		message(FATAL_ERROR "vcpkg depend-info command generated some stderr content:\n${stderr_content}")
	endif()
	if(NOT depend_info MATCHES "docwire: ")
		message(FATAL_ERROR "Something is wrong with vcpkg depend-info command result:\n${depend_info}")
	endif()
	message("Parsing dependencies")
	string(REPLACE "\n" ";" dep_info_list ${depend_info})
	foreach(d ${dep_info_list})
		string(REGEX MATCH [^:[]+ port_name ${d})
		string(REGEX REPLACE [^:]+: "" deps ${d})
		string(REGEX MATCHALL [a-z-]+ deps ${deps})
		list(APPEND all_ports ${port_name})
		set(port_dependencies_cached_result_${port_name} ${deps} CACHE INTERNAL "")
		message("port_dependencies_cached_result_${port_name}=${port_dependencies_cached_result_${port_name}}")
		foreach(dep in ${deps})
			list(APPEND port_required_by_${dep} ${port_name})
			set(port_required_by_cached_result_${dep} ${port_required_by_${dep}} CACHE INTERNAL "")
		endforeach()
	endforeach()
	set(dependencies_list_cached_result ${all_ports} CACHE INTERNAL "")
endfunction()

function(port_dependencies port_name out_var)
	if(NOT DEFINED port_dependencies_cached_result_${port_name})
		port_dependencies_internal()
	endif()
	set(${out_var} ${port_dependencies_cached_result_${port_name}} PARENT_SCOPE)
endfunction()

function(port_required_by port_name out_var)
	if(NOT DEFINED port_required_by_cached_result_${port_name})
		port_dependencies_internal()
	endif()
	set(${out_var} ${port_required_by_cached_result_${port_name}} PARENT_SCOPE)
endfunction()

function(dependencies_list out_var)
	if(NOT DEFINED dependencies_list_cached_result)
		port_dependencies_internal()
	endif()
	set(${out_var} ${dependencies_list_cached_result} PARENT_SCOPE)
endfunction()

function(docwire_modules_using_dependency port_name out_var)
	if(NOT DEFINED docwire_modules_using_dependency_cached_result_${port_name})
		message("Searching for docwire modules using dependency ${port_name}")
		set(docwire_core_deps vcpkg-cmake libcharsetdetect wv2 boost-filesystem boost-dll boost-signals2 boost-json boost-program-options magic-enum podofo unzip htmlcxx pthread gtest curlpp cmap-resources mapping-resources-pdf)
		set(docwire_ocr_deps tesseract tessdata-fast)
		set(docwire_mail_deps libpff-unix libbfio mailio)
		set(modules "")
		foreach(module docwire_core docwire_ocr docwire_mail)
			list(FIND ${module}_deps ${port_name} deps_index)
			if(NOT ${deps_index} EQUAL -1)
				list(APPEND modules ${module})
			endif()
		endforeach()
		port_required_by(${port_name} required_by)
		foreach(req ${required_by})
			docwire_modules_using_dependency(${req} req_mods)
			list(APPEND modules ${req_mods})
			list(REMOVE_DUPLICATES modules)
		endforeach()
		set(docwire_modules_using_dependency_cached_result_${port_name} ${modules} CACHE INTERNAL "")
	endif()
	set(${out_var} ${docwire_modules_using_dependency_cached_result_${port_name}} PARENT_SCOPE)
endfunction()

function(vcpkg_package_info out_var)
	if(NOT DEFINED vcpkg_package_info_cached_result)
		dependencies_list(all_ports)
		message("Executing ${CMAKE_SOURCE_DIR}/vcpkg/vcpkg x-package-info --overlay-ports=${CMAKE_SOURCE_DIR}/ports --x-json ${all_ports}")
		execute_process(COMMAND ${CMAKE_SOURCE_DIR}/vcpkg/vcpkg x-package-info --overlay-ports=${CMAKE_SOURCE_DIR}/ports --x-json ${all_ports} OUTPUT_VARIABLE package_info ERROR_VARIABLE stderr_content)
		if(NOT stderr_content STREQUAL "")
			message(FATAL_ERROR "vcpkg x-package-info command generated some stderr content:\n${stderr_content}")
		endif()
		if(NOT package_info MATCHES "\"dependencies\"")
			message(FATAL_ERROR "Something is wrong with vcpkg x-package-info command result:\n${package_info}")
		endif()
		string(JSON package_info_json GET ${package_info} results)
		message("package_info_json=${package_info_json}")
		string(REGEX REPLACE "\n" "" package_info_json "${package_info_json}")
		set(vcpkg_package_info_cached_result ${package_info_json} CACHE INTERNAL "")
	endif()
	set(${out_var} ${vcpkg_package_info_cached_result} PARENT_SCOPE)
endfunction()

function(port_vcpkg_json port_name out_var)
	if(NOT DEFINED port_vcpkg_cached_result_${port_name})
		message("Extracting vcpkg_json")
		vcpkg_package_info(package_info_json)
		string(JSON vcpkg_json GET ${package_info_json} ${port_name})
		string(REGEX REPLACE "\n" "" vcpkg_json "${vcpkg_json}")
		set(port_vcpkg_cached_result_${port_name} ${vcpkg_json} CACHE INTERNAL "")
	endif()
	set(${out_var} ${port_vcpkg_cached_result_${port_name}} PARENT_SCOPE)
endfunction()

function(extract_full_license_info port_name out_var)
	message("Extracting full license info")
	file(READ ${CMAKE_SOURCE_DIR}/vcpkg/installed/${VCPKG_TARGET_TRIPLET}/share/${port_name}/copyright copyright_text)
	set(${out_var} ${copyright_text} PARENT_SCOPE)
endfunction()

function(extract_version port_name out_var)
	message("Extracting version")
	port_vcpkg_json(${port_name} vcpkg_json)
	foreach(version_field version version-semver version-date version-string)
		string(JSON version ERROR_VARIABLE err GET ${vcpkg_json} ${version_field})
		if (NOT ${version} STREQUAL ${version_field}-NOTFOUND)
			set(${out_var} ${version} PARENT_SCOPE)
			return()
		endif()
	endforeach()
	message(FATAL_ERROR "Version of ${port_name} not found")
endfunction()

function(extract_homepage port_name out_var)
	message("Extracting homepage")
	if(${port_name} STREQUAL boost-vcpkg-helpers)
		set(${out_var} "Automatically generated by VCPKG scripts")
		return()
	endif()
	if(${port_name} STREQUAL curlpp)
		set(${out_var} "https://github.com/jpbarrette/curlpp")
		return()
	endif()
	if(${port_name} STREQUAL pthread)
		set(${out_var} "Empty package, linking to other port")
		return()
	endif()
	port_vcpkg_json(${port_name} vcpkg_json)
	string(JSON homepage GET ${vcpkg_json} homepage)
	set(${out_var} ${homepage} PARENT_SCOPE)
endfunction()

function(extract_license_expression port_name out_var)
	message("Extracting license expression")
	port_vcpkg_json(${port_name} vcpkg_json)
	string(JSON license ERROR_VARIABLE err GET ${vcpkg_json} license)
	if (NOT ${license} STREQUAL license-NOTFOUND)
		set(${out_var} ${license} PARENT_SCOPE)
		return()
	endif()
	set(license_curlpp MIT)
	set(license_libiconv LGPL-2.1-only AND GPL-3.0-only)
	set(license_libarchive BSD-2-Clause)
	set(license_leptonica  BSD-2-Clause)
	if (DEFINED license_${port_name})
		set(${out_var} ${license_${port_name}} PARENT_SCOPE)
		return()
	endif()
	message(FATAL_ERROR "License expression for ${port_name} not found")
endfunction()

function(simplify_spdx_license_expression expression out_var)
	message("simplify_spdx_license_expression(${expression})")
	string(REPLACE "GPL-2.0-only OR LGPL-2.1-only" "LGPL-2.1-only" expression ${expression})
	string(REPLACE "MPL-1.1 OR LGPL-2.1-only" "LGPL-2.1-only" expression ${expression})
	string(REPLACE "(LGPL-2.1-only)" "LGPL-2.1-only" expression ${expression})
	string(REPLACE "(BSD-3-Clause AND LGPL-2.1-only)" "BSD-3-Clause AND LGPL-2.1-only" expression ${expression})
	string(REPLACE "LGPL-2.1-only AND BSD-3-Clause AND LGPL-2.1-only" "BSD-3-Clause AND LGPL-2.1-only" expression ${expression})
	set(${out_var} ${expression} PARENT_SCOPE)
endfunction()

function(parse_spdx_license_expression expression out_var)
	message("expression=${expression}")
	string(REGEX MATCHALL [a-zA-Z0-9.-]+ tokens ${expression})
	message("tokens=${tokens}")
	list(FILTER tokens EXCLUDE REGEX "AND|OR")
	set(${out_var} ${tokens} PARENT_SCOPE)
endfunction()

function(license_description_from_license_id license_id out_var)
	string(REPLACE "-only" "" license_id ${license_id})
	string(REPLACE "-or-later" "" license_id ${license_id})
	# license descriptions from https://choosealicense.com
	set(license_desc_BSL-1.0 "A simple permissive license only requiring preservation of copyright and license notices for source (and not binary) distribution. Licensed works, modifications, and larger works may be distributed under different terms and without source code.")
	set(license_desc_MIT "A short and simple permissive license with conditions only requiring preservation of copyright and license notices. Licensed works, modifications, and larger works may be distributed under different terms and without source code.")
	set(license_desc_BSD-2-Clause "A permissive license that comes in two variants, the BSD 2-Clause and BSD 3-Clause. Both have very minute differences to the MIT license.")
	set(license_desc_BSD-3-Clause "A permissive license similar to the BSD 2-Clause License, but with a 3rd clause that prohibits others from using the name of the copyright holder or its contributors to promote derived products without written consent.")
	set(license_desc_GPL-2.0 "The GNU GPL is the most widely used free software license and has a strong copyleft requirement. When distributing derived works, the source code of the work must be made available under the same license. There are multiple variants of the GNU GPL, each with different requirements.")
	set(license_desc_ISC "A permissive license lets people do anything with your code with proper attribution and without warranty. The ISC license is functionally equivalent to the BSD 2-Clause and MIT licenses, removing some language that is no longer necessary.")
	set(license_desc_Zlib "A short permissive license, compatible with GPL. Requires altered source versions to be documented as such.")
	set(license_desc_LGPL-2.1 "Primarily used for software libraries, the GNU LGPL requires that derived works be licensed under the same license, but works that only link to it do not fall under this restriction. There are two commonly used versions of the GNU LGPL.")
	set(license_desc_LGPL-3.0 "Permissions of this copyleft license are conditioned on making available complete source code of licensed works and modifications under the same license or the GNU GPLv3. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. However, a larger work using the licensed work through interfaces provided by the licensed work may be distributed under different terms and without source code for the larger work.")
	set(license_desc_Apache-2.0 "A permissive license whose main conditions require preservation of copyright and license notices. Contributors provide an express grant of patent rights. Licensed works, modifications, and larger works may be distributed under different terms and without source code.")
	# license description from https://curl.se/docs/copyright.html
	set(license_desc_curl "It means that you are free to modify and redistribute all contents of the curl distributed archives. You may also freely use curl and libcurl in your commercial projects. Curl and libcurl are licensed under the license below, which is inspired by MIT/X, but not identical.")
	# license description from https://freetype.org/license.html
	set(license_desc_FTL "The FreeType License (FTL) is the most commonly used one. It is a BSD-style license with a credit clause and thus compatible with the GNU Public License (GPL) version 3, but not with the GPL version 2.")
	# license description generated from http://www.libpng.org/pub/png/src/libpng-LICENSE.txt
	set(license_desc_libpng-2.0 "The libpng-2.0 license is a permissive open-source license that allows the use, modification, and distribution of the libpng library in both commercial and non-commercial projects, with a disclaimer of warranty.")
	# license description from https://gitlab.com/libtiff/libtiff
	set(license_desc_libtiff "Silicon Graphics has seen fit to allow us to give this work away. It is free. There is no support or guarantee of any sort as to its operations, correctness, or whatever. If you do anything useful with all or parts of it you need to honor the copyright notices. I would also be interested in knowing about it and, hopefully, be acknowledged.")
	# reuse description. LGPL-2.1 introduced only updates and clarifications
	set(license_desc_LGPL-2.0 ${license_desc_LGPL-2.1})
	if (DEFINED license_desc_${license_id})
		set(${out_var} ${license_desc_${license_id}} PARENT_SCOPE)
		return()
	endif()
	#set(${out_var} "?" PARENT_SCOPE)
	message(FATAL_ERROR "License description for ${license_id} not found")
endfunction()

function(write_dependencies file_name port_name)
	message("Analysing dependencies")
	port_dependencies(${port_name} port_deps)
	message("dependencies of ${port_name}=${port_deps}")
	port_vcpkg_json(${port_name} vcpkg_json)
	string(JSON deps_length LENGTH ${vcpkg_json} dependencies)
	math(EXPR max_dep_index ${deps_length}-1)
	foreach(n RANGE ${max_dep_index})
		string(JSON dep_type TYPE ${vcpkg_json} dependencies ${n})
		string(JSON dep GET ${vcpkg_json} dependencies ${n})
		if(${dep_type} STREQUAL STRING)
			set(dep_name ${dep})
			set(dep_host OFF)
		else()
			string(JSON dep_name GET ${dep} name)
			string(JSON dep_host ERROR_VARIABLE err GET ${dep} host)
			if (dep_host STREQUAL host-NOTFOUND)
				set(dep_host OFF)
			endif()
		endif()
		message(dep_name: ${dep_name})
		message(dep_host: ${dep_host})
		if(${dep_name} STREQUAL boost-uninstall OR ${dep_name} STREQUAL libiconv OR ${dep_name} STREQUAL pthread)
			continue() # empty package
		endif()
		if(${dep_host})
			continue()
		endif()
		list(FIND port_deps ${dep_name} deps_index)
		if(deps_index EQUAL -1)
			message("Not linked on this platform")
			continue()
		endif()
		write_port_info(${file_name} ${dep_name})
	endforeach()
endfunction()

function(write_port_info file_name port_name)
	list(FIND printed_ports ${port_name} printed_ports_index)
	if(NOT printed_ports_index EQUAL -1)
		return()
	endif()
	message("*** Processing ${port_name} ...")
	extract_version(${port_name} version)
	extract_homepage(${port_name} homepage)
	port_required_by(${port_name} required_by)
	docwire_modules_using_dependency(${port_name} modules)
	extract_license_expression(${port_name} license_expr)
	file(APPEND ${file_name}
		"## ${port_name}\n\n"
		"### Basic information\n\n"
		"Version: ${version}\n\n"
		"Homepage: ${homepage}\n\n"
		"Required by: ${required_by}\n\n"
		"DocWire modules: ${modules}\n\n")
	file(APPEND ${file_name} "### Short license summary\n\n")
	file(APPEND ${file_name} "Full SPDX-License-Identifier: ${license_expr}\n\n")
	simplify_spdx_license_expression(${license_expr} license_expr)
	file(APPEND ${file_name} "Simplified SPDX-License-Identifier: ${license_expr}\n\n")
	parse_spdx_license_expression(${license_expr} license_ids)
	message("licenses_ids=${license_ids}")
	foreach(license_id ${license_ids})
		license_description_from_license_id(${license_id} license_desc)
		file(APPEND ${file_name} "${license_id}: ${license_desc}\n\n")
	endforeach()
	extract_full_license_info(${port_name} copyright_text)
	file(APPEND ${file_name}
		"### Full copyright information and disclaimer\n"
		"```\n"
		"${copyright_text}\n"
		"```\n\n")
	write_dependencies(${file_name} ${port_name})
	message("Port ${port_name} processed")
	list(APPEND printed_ports ${port_name})
	set(printed_ports ${printed_ports} CACHE INTERNAL "")
endfunction()

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/3rdparty_components.md
	"# 3rdparty components used\n\n"
	"The DocWire SDK incorporates code that falls under licenses separate from the GNU General Public License or the DocWire Commercial License;\n"
	"instead, it operates under specific licenses granted by the original authors.\n\n"
	"We express our gratitude for all contributions to the DocWire SDK and encourage users to acknowledge these contributions.\n"
	"It is recommended that programs using the SDK include these acknowledgments, along with relevant license statements and disclaimers,\n"
	"in an appendix to the documentation.\n\n"
	"It's important to note that all third-party components integrated into the DocWire SDK are licensed under open-source licenses.\n"
	"This allows their free usage, even in closed-source commercial software, without incurring licensing fees.\n\n"
	"Compliance with and acknowledgment of the licenses associated with third-party components is required only for those specific components used in your application.\n\n")
if (DEFINED ENV{READTHEDOCS})
	file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/3rdparty_components.md
		"Due to the platform-dependent nature of SDK compilation, the comprehensive list of components is included in the offline documentation,\n"
		"conveniently situated in the same section as this statement within the online documentation.\n"
		"Access to this information is available upon the successful compilation of the SDK on the designated platform.\n\n")
else()
	if (NOT DEFINED VCPKG_TARGET_TRIPLET)
		message(FATAL_ERROR "VPKG_TARGET_TRIPLET must be set.")
	endif()
	file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/3rdparty_components.md
		"For a convenient and swift application of all necessary statements, you can utilize the following summary:\n\n")
	write_dependencies(${CMAKE_CURRENT_BINARY_DIR}/3rdparty_components.md docwire)
endif()
