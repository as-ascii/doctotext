if(DEFINED ENV{SOURCE_PATH})
	set(SOURCE_PATH $ENV{SOURCE_PATH})
else()
	vcpkg_from_github(
		OUT_SOURCE_PATH SOURCE_PATH
		REPO docwire/docwire
		REF 2024.01.05
		SHA512 8d16d7172897775adbbe8891ddb7326708a0e7d0a23961294ec1251af95b4b0af5689066594495b9327d50183080d98baa1d6f2002cdc1b285cef3683bc7af42
		HEAD_REF master
	)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
	set(LIB_DIR_NAME bin)
else()
	set(LIB_DIR_NAME lib)
endif()

vcpkg_cmake_configure(
	SOURCE_PATH "${SOURCE_PATH}"
	OPTIONS ${FEATURE_OPTIONS}
	OPTIONS_RELEASE
		"-DTEST_PREPEND_LIBRARY_PATH=${CURRENT_PACKAGES_DIR}/${LIB_DIR_NAME};${CURRENT_INSTALLED_DIR}/${LIB_DIR_NAME}"
	OPTIONS_DEBUG
		"-DTEST_PREPEND_LIBRARY_PATH=${CURRENT_PACKAGES_DIR}/debug/${LIB_DIR_NAME};${CURRENT_INSTALLED_DIR}/debug/${LIB_DIR_NAME}"
)

set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP FALSE)

vcpkg_cmake_install()

if(VCPKG_TARGET_IS_WINDOWS)
	set(script_suffix .bat)
else()
	set(script_suffix .sh)
endif()

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools)
file(RENAME
	"${CURRENT_PACKAGES_DIR}/bin/docwire${VCPKG_TARGET_EXECUTABLE_SUFFIX}"
	"${CURRENT_PACKAGES_DIR}/tools/docwire${VCPKG_TARGET_EXECUTABLE_SUFFIX}"
)
if (EXISTS "${CURRENT_PACKAGES_DIR}/bin/docwire${script_suffix}") # Removed in new release
	file(RENAME "${CURRENT_PACKAGES_DIR}/bin/docwire${script_suffix}" "${CURRENT_PACKAGES_DIR}/tools/docwire${script_suffix}")
endif()
file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/debug/tools)
file(RENAME
	"${CURRENT_PACKAGES_DIR}/debug/bin/docwire${VCPKG_TARGET_EXECUTABLE_SUFFIX}"
	"${CURRENT_PACKAGES_DIR}/debug/tools/docwire${VCPKG_TARGET_EXECUTABLE_SUFFIX}"
)
if (EXISTS "${CURRENT_PACKAGES_DIR}/debug/bin/docwire${script_suffix}") # Removed in new release
	file(RENAME "${CURRENT_PACKAGES_DIR}/debug/bin/docwire${script_suffix}" "${CURRENT_PACKAGES_DIR}/debug/tools/docwire${script_suffix}")
endif()
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static" OR NOT VCPKG_TARGET_IS_WINDOWS)
	file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_LIST ${SOURCE_PATH}/LICENSE ${SOURCE_PATH}/doc/COPYING.GPLv2)

function(run_tests build_type)
	set(triplet_build_type ${TARGET_TRIPLET}-${build_type})
	message(STATUS "Testing ${triplet_build_type}")
	vcpkg_execute_required_process(
		COMMAND "ctest"
			-V
			--no-tests=error
		WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${triplet_build_type}
		LOGNAME test-${PORT}-${triplet_build_type}
	)
endfunction()

function(run_all_tests)
	if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL debug)
		run_tests(dbg)
	endif()
	if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL release)
		run_tests(rel)
	endif()
endfunction()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS_NO_CMAKE
	FEATURES
		tests TESTS_ENABLED
)

if (TESTS_ENABLED)
	run_all_tests()
endif()
