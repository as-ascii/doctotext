add_library(docwire_iwork SHARED iwork_parser.cpp)

target_link_libraries(docwire_iwork PRIVATE docwire_core)
find_path(wv2_incdir wv2/ustring.h) # because of misc.h, TODO: misc.h should be splitted
target_include_directories(docwire_iwork PRIVATE ${wv2_incdir})

install(TARGETS docwire_iwork)
if(MSVC)
	install(FILES $<TARGET_PDB_FILE:docwire_iwork> DESTINATION bin CONFIGURATIONS Debug)
endif()