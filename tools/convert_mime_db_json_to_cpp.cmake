cmake_minimum_required(VERSION 3.19) # because of json
file(READ "db.json" json_data)
string(JSON length LENGTH ${json_data})
math(EXPR last "${length}-1")
file(WRITE "db.json.cpp"
    "const std::unordered_multimap<std::string, std::string> file_extension_to_mime_type = {\n"
    "\t// this part is generated by tools/convert_mime_db_json_to_cpp.cmake\n"
    "\t// from https://github.com/jshttp/mime-db (MIT license)\n"
)
foreach(index RANGE ${last})
    string(JSON key MEMBER ${json_data} ${index})
    message("key: ${key}")
    string(JSON data GET ${json_data} ${key})
    string(JSON extensions ERROR_VARIABLE error GET ${data} extensions)
    if(extensions MATCHES extensions-NOTFOUND)
        continue()
    endif()
    string(JSON extensions_length LENGTH ${data} extensions)
    math(EXPR extensions_last "${extensions_length}-1")
    foreach(extension_index RANGE ${extensions_last})
        string(JSON extension GET ${extensions} ${extension_index})
        file(APPEND "db.json.cpp"
            "\t{\".${extension}\", \"${key}\"},\n"
        )
    endforeach()
endforeach()
file(APPEND "db.json.cpp"
  "};\n"
)
