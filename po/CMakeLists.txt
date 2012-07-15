file(GLOB list_po RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.po)

foreach(file_po ${list_po})
	string(REPLACE ".po" ".mo" file_mo ${file_po})
	add_custom_target(${file_mo} ALL
          DEPENDS ${file_po}
          COMMAND msgfmt ${file_po} -o ${file_mo}
        )
endforeach()

foreach(file_po ${list_po})
	string(REPLACE ".po" ".mo" file_mo ${file_po})
	string(REPLACE ".mo" "" file_lang ${file_mo})
	install(FILES
        	${file_mo}
	DESTINATION
        	share/locale/${file_lang}/LC_MESSAGES
	RENAME pdfpc.mo
	)
endforeach()

