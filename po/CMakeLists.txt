file(GLOB list_po RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.po)

foreach(file_po ${list_po})
	string(REPLACE ".po" ".mo" file_mo ${file_po})
	add_custom_target(${file_mo} ALL
          DEPENDS ${file_po}
          COMMAND msgfmt ${file_po} -o ${file_mo}
        )
endforeach()

install(FILES
        es.mo
DESTINATION
        share/locale/es/LC_MESSAGES
RENAME pdfpc.mo
)

install(FILES
        gl.mo
DESTINATION
        share/locale/gl/LC_MESSAGES
RENAME pdfpc.mo
)
