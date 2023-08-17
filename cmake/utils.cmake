# Get doctotext version from ChangeLog and store it in DOCTOTEXT_VERSION and SIMPLE_DOCTOTEXT_VERSION
function(doctotext_extract_version)
	file(READ "${CMAKE_CURRENT_SOURCE_DIR}/ChangeLog" changelog_text)
	if(${changelog_text} MATCHES "Version ([0-9]+\\.[0-9]+\\.[0-9]+):")
		set(simple_doc_ver ${CMAKE_MATCH_1})
	else()
		message(FATAL_ERROR "Could not extract version number from ChangeLog")
	endif()
	if (changelog_text MATCHES "Unreleased")
		set(doc_ver ${simple_doc_ver}-dirty)
	else()
		set(doc_ver ${simple_doc_ver})
	endif()
	set(DOCTOTEXT_VERSION ${doc_ver} PARENT_SCOPE)
	set(SIMPLE_DOCTOTEXT_VERSION ${simple_doc_ver} PARENT_SCOPE)
endfunction()
