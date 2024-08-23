cmake_minimum_required(VERSION 3.19) # because of json

function(traverse_dependency_tree_from_vcpkg_json_dependencies_array dependencies_arr port_name)
	string(JSON deps_length LENGTH ${dependencies_arr})
	math(EXPR max_dep_index ${deps_length}-1)
	foreach(n RANGE ${max_dep_index})
		string(JSON dep_type TYPE ${dependencies_arr} ${n})
		string(JSON dep GET ${dependencies_arr} ${n})
		message("dep=${dep}")
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
		string(JSON dep_platform ERROR_VARIABLE err GET ${dep} platform)
		if (dep_platform MATCHES NOTFOUND)
			set(dep_platform "none")
		endif()
		platform_expression_matches_target(${dep_platform} dep_platform_matches)
		if(NOT dep_platform_matches)
			message("Skipping dependency for this platform")
			continue()
		endif()
		string(JSON dep_default_features ERROR_VARIABLE err GET ${dep} default-features)
		if (dep_default_features MATCHES NOTFOUND)
			set(dep_default_features TRUE)
		endif()
		json_array_to_list(${dep} features dep_features)
		message(dep_name: ${dep_name})
		message(dep_host: ${dep_host})
		message("dep_default_features: ${dep_default_features}")
		message("dep_features: ${dep_features}")
		message(dep_platform: ${dep_platform})
		message(dep_platform_matches: ${dep_platform_matches})
		if(${dep_host})
			continue()
		endif()
		list(APPEND traverse_dependency_tree_cached_all_port_names ${dep_name})
		list(REMOVE_DUPLICATES traverse_dependency_tree_cached_all_port_names)
		set(traverse_dependency_tree_cached_all_port_names ${traverse_dependency_tree_cached_all_port_names} CACHE INTERNAL "")
		if (NOT ${dep_name} STREQUAL ${port_name})
			list(APPEND traverse_dependency_tree_cached_${dep_name}_is_required_by ${port_name})
			list(REMOVE_DUPLICATES traverse_dependency_tree_cached_${dep_name}_is_required_by)
			set(traverse_dependency_tree_cached_${dep_name}_is_required_by ${traverse_dependency_tree_cached_${dep_name}_is_required_by} CACHE INTERNAL "")
		endif()
		traverse_dependency_tree_from_port(${dep_name} ${dep_default_features} "${dep_features}")
	endforeach()
endfunction()

function(json_array_to_list json array_name out_var)
	string(JSON length ERROR_VARIABLE err LENGTH ${json} ${array_name})
	if(length MATCHES NOTFOUND)
		set(${out_var} "" PARENT_SCOPE)
		return()
	endif()
	math(EXPR max_index ${length}-1)
	set(result "")
	foreach(n RANGE ${max_index})
		string(JSON item GET ${json} ${array_name} ${n})
		list(APPEND result ${item})
	endforeach()
	set(${out_var} ${result} PARENT_SCOPE)
endfunction()

function(port_default_features port_name out_var)
	message("Loading ${port_name} default features")
	port_vcpkg_json(${port_name} vcpkg_json)
	string(JSON length ERROR_VARIABLE err LENGTH ${vcpkg_json} default-features)
	if(length MATCHES NOTFOUND)
		set(${out_var} "" PARENT_SCOPE)
		return()
	endif()
	math(EXPR max_index ${length}-1)
	set(features "")
	foreach(n RANGE ${max_index})
		string(JSON feature GET ${vcpkg_json} default-features ${n})
		list(APPEND features ${feature})
	endforeach()
	set(${out_var} ${features} PARENT_SCOPE)
endfunction()

function(traverse_dependency_tree_from_port port_name use_default_features features)
	set(use_default_features TRUE) # this is forced in non-manifest mode, TODO: update if manifest-mode is implemented
	if(${use_default_features})
		port_default_features(${port_name} def_features)
		list(APPEND features ${def_features})
	endif()
	list(JOIN features "_" features_str)
	if(NOT DEFINED traverse_dependency_tree_from_port_${port_name}_${features_str})
		message("Traversing dependencies tree from ${port_name} with features \"${features}\"")
		set(traverse_dependency_tree_from_port_${port_name}_${features_str} TRUE CACHE INTERNAL "")
		port_vcpkg_json(${port_name} vcpkg_json)
		string(JSON dependencies_arr ERROR_VARIABLE err GET ${vcpkg_json} dependencies)
		if(NOT dependencies_arr MATCHES NOTFOUND)
			traverse_dependency_tree_from_vcpkg_json_dependencies_array(${dependencies_arr} ${port_name})
		endif()
		message("features=${features}")
		foreach(feature ${features})
			message("feature=${feature}")
			string(JSON feature_json GET ${vcpkg_json} features ${feature})
			message("feature_json=${feature_json}")
			string(JSON feature_deps_arr ERROR_VARIABLE err GET ${feature_json} dependencies)
			if(feature_deps_arr MATCHES NOTFOUND)
				continue()
			endif()
			traverse_dependency_tree_from_vcpkg_json_dependencies_array(${feature_deps_arr} ${port_name})
		endforeach()
	endif()
endfunction()

function(traverse_whole_dependency_tree)
	traverse_dependency_tree_from_port(docwire TRUE "")
endfunction()

function(all_dependencies out_var)
	if(NOT DEFINED traverse_dependency_tree_cached_all_port_names)
		traverse_whole_dependency_tree()
	endif()
	set(${out_var} ${traverse_dependency_tree_cached_all_port_names} PARENT_SCOPE)
endfunction()

function(port_required_by port_name out_var)
	if(NOT DEFINED traverse_dependency_tree_cached_${port_name}_is_required_by)
		traverse_whole_dependency_tree()
	endif()
	set(${out_var} ${traverse_dependency_tree_cached_${port_name}_is_required_by} PARENT_SCOPE)
endfunction()

function(docwire_modules_using_dependency port_name out_var)
	if(NOT DEFINED docwire_modules_using_dependency_cached_result_${port_name})
		message("Searching for docwire modules using dependency ${port_name}")
		set(docwire_core_deps vcpkg-cmake wv2 boost-filesystem boost-dll boost-signals2 boost-json magic-enum unzip zlib gtest curlpp libarchive)
		set(docwire_html_deps htmlcxx libcharsetdetect)
		set(docwire_pdf_deps podofo cmap-resources mapping-resources-pdf zlib)
		set(docwire_ocr_deps tesseract tessdata-fast leptonica)
		set(docwire_rtf_deps wv2)
		set(docwire_xml_deps libxml2)
		set(docwire_mail_deps libpff libpff-unix libbfio mailio htmlcxx boost-date-time)
		set(docwire_xlsb wv2)
		set(docwire_iwork wv2)
		set(docwire_odf_ooxml wv2)
		set(docwire_ole_office_formats wv2)
		set(docwire_plain_text libcharsetdetect htmlcxx)
		set(docwire_local_ai boost-filesystem boost-system boost-json ctranslate2 opennmt-tokenizer flan-t5-large-ct2-int8)
		set(docwire_fuzzy_match rapidfuzz)
		set(docwire_base64 aklomp-base64)
		set(docwire_cli_deps boost-program-options)
		set(modules "")
		foreach(module docwire_core docwire_html docwire_pdf docwire_ocr docwire_rtf docwire_xml docwire_mail docwire_xlsb docwire_iwork docwire_odf_ooxml docwire_ole_office_formats docwire_plain_text docwire_local_ai docwire_fuzzy_match docwire_base64 docwire_cli)
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

function(port_vcpkg_json port_name out_var)
	if(NOT DEFINED port_vcpkg_cached_result_${port_name})
		message("Extracting vcpkg_json")
		if (EXISTS ${VCPKG_INSTALLED_DIR}/../ports/${port_name}/vcpkg.json)
			file(READ ${VCPKG_INSTALLED_DIR}/../ports/${port_name}/vcpkg.json vcpkg_json)
		elseif (EXISTS ${CMAKE_SOURCE_DIR}/ports/${port_name}/vcpkg.json)
			file(READ ${CMAKE_SOURCE_DIR}/ports/${port_name}/vcpkg.json vcpkg_json)
		else()
			message(FATAL_ERROR "Cannot find vcpkg.json file for ${port_name} port")
		endif()
		string(REGEX REPLACE "\n" "" vcpkg_json "${vcpkg_json}")
		set(port_vcpkg_cached_result_${port_name} ${vcpkg_json} CACHE INTERNAL "")
	endif()
	set(${out_var} ${port_vcpkg_cached_result_${port_name}} PARENT_SCOPE)
endfunction()

function(extract_full_license_info port_name out_var)
	message("Extracting full license info")
	if (port_name STREQUAL gettext-libintl)
		set(port_name gettext)
	endif()
	file(READ ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/share/${port_name}/copyright copyright_text)
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
	port_vcpkg_json(${port_name} vcpkg_json)
	string(JSON homepage GET ${vcpkg_json} homepage)
	set(${out_var} ${homepage} PARENT_SCOPE)
endfunction()

function(extract_license_expression port_name out_var)
	message("Extracting license expression")
	if(port_name STREQUAL gettext)
		set(${out_var} "LGPL-2.1-only AND GPL-3.0-only" PARENT_SCOPE) # rewrite incorrect license
		return()
	endif()
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
	set(license_liblzma Unlicense)
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
	set(license_desc_GPL-3.0 "Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications, which include larger works using a licensed work, under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights.")
	set(license_desc_ISC "A permissive license lets people do anything with your code with proper attribution and without warranty. The ISC license is functionally equivalent to the BSD 2-Clause and MIT licenses, removing some language that is no longer necessary.")
	set(license_desc_Zlib "A short permissive license, compatible with GPL. Requires altered source versions to be documented as such.")
	set(license_desc_LGPL-2.1 "Primarily used for software libraries, the GNU LGPL requires that derived works be licensed under the same license, but works that only link to it do not fall under this restriction. There are two commonly used versions of the GNU LGPL.")
	set(license_desc_LGPL-3.0 "Permissions of this copyleft license are conditioned on making available complete source code of licensed works and modifications under the same license or the GNU GPLv3. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. However, a larger work using the licensed work through interfaces provided by the licensed work may be distributed under different terms and without source code for the larger work.")
	set(license_desc_Apache-2.0 "A permissive license whose main conditions require preservation of copyright and license notices. Contributors provide an express grant of patent rights. Licensed works, modifications, and larger works may be distributed under different terms and without source code.")
	set(license_desc_Unlicense "A license with no conditions whatsoever which dedicates works to the public domain. Unlicensed works, modifications, and larger works may be distributed under different terms and without source code.")
	# license description from https://curl.se/docs/copyright.html
	set(license_desc_curl "It means that you are free to modify and redistribute all contents of the curl distributed archives. You may also freely use curl and libcurl in your commercial projects. Curl and libcurl are licensed under the license below, which is inspired by MIT/X, but not identical.")
	# license description from https://freetype.org/license.html
	set(license_desc_FTL "The FreeType License (FTL) is the most commonly used one. It is a BSD-style license with a credit clause and thus compatible with the GNU Public License (GPL) version 3, but not with the GPL version 2.")
	# license description generated from http://www.libpng.org/pub/png/src/libpng-LICENSE.txt
	set(license_desc_libpng-2.0 "The libpng-2.0 license is a permissive open-source license that allows the use, modification, and distribution of the libpng library in both commercial and non-commercial projects, with a disclaimer of warranty.")
	# license description generated from LICENSE file
	set(license_desc_bzip2-1.0.6 "bzip2 license is similar to the standard BSD 3-Clause License with some specific wording related to marking altered source versions.")
	# license description from https://gitlab.com/libtiff/libtiff
	set(license_desc_libtiff "Silicon Graphics has seen fit to allow us to give this work away. It is free. There is no support or guarantee of any sort as to its operations, correctness, or whatever. If you do anything useful with all or parts of it you need to honor the copyright notices. I would also be interested in knowing about it and, hopefully, be acknowledged.")
	# license description from https://icu.unicode.org/
	set(license_desc_ICU "Nonrestrictive open source license that is suitable for use with both commercial software and with other open source or free software.")
	# reuse description. LGPL-2.1 introduced only updates and clarifications
	set(license_desc_LGPL-2.0 ${license_desc_LGPL-2.1})
	if (DEFINED license_desc_${license_id})
		set(${out_var} ${license_desc_${license_id}} PARENT_SCOPE)
		return()
	endif()
	message(FATAL_ERROR "License description for ${license_id} not found")
endfunction()

function(platform_expression_matches_target platform_expr out_var)
	if(platform_expr STREQUAL "none")
		set(${out_var} TRUE PARENT_SCOPE)
		return()
	endif()
	foreach(identifier windows uwp osx ios mingw arm android emscripten linux x64)
		if (VCPKG_TARGET_TRIPLET MATCHES "${identifier}")
			set(${identifier} TRUE)
		else()
			set(${identifier} FALSE)
		endif()
	endforeach()
	if(${windows} OR ${uwp} OR ${mingw})
		set(windows TRUE)
	else()
		set(windows FALSE)
	endif()
	string(REGEX MATCHALL "[^&|!() ]+" identifiers ${platform_expr})
	foreach(identifier ${identifiers})
		if (NOT DEFINED ${identifier})
			message(FATAL_ERROR "Unknown platform expression identifier: \"${identifier}\"")
		endif()
	endforeach()
	string(REPLACE "&" " AND " platform_expr ${platform_expr})
	string(REPLACE "|" " OR " platform_expr ${platform_expr})
	string(REPLACE "!" "NOT " platform_expr ${platform_expr})
	cmake_language(EVAL CODE "
		if(${platform_expr})
			set(matches TRUE)
		else()
			set(matches FALSE)
		endif()")
	set(${out_var} ${matches} PARENT_SCOPE)
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
	message("Port ${port_name} processed")
	list(APPEND printed_ports ${port_name})
	set(printed_ports ${printed_ports} CACHE INTERNAL "")
endfunction()

function(check_if_empty_package port_name out_var)
	if(${port_name} STREQUAL getopt OR ${port_name} STREQUAL boost-uninstall OR ${port_name} STREQUAL pthread)
		set(${out_var} TRUE PARENT_SCOPE)
	elseif(${port_name} STREQUAL dirent AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "uwp")
		set(${out_var} TRUE PARENT_SCOPE)
	elseif(${port_name} STREQUAL libiconv AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "windows" AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "uwp" AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "mingw" AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "android")
		set(${out_var} TRUE PARENT_SCOPE)
	elseif(${port_name} STREQUAL pthreads AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "windows" AND NOT ${VCPKG_TARGET_TRIPLET} MATCHES "uwp")
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
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
	all_dependencies(dependencies)
	foreach(dep ${dependencies})
		check_if_empty_package(${dep} is_empty_package)
		if(is_empty_package)
			continue()
		endif()
		write_port_info(${CMAKE_CURRENT_BINARY_DIR}/3rdparty_components.md ${dep})
	endforeach()
endif()
