set(TOP_SRCDIR "${CMAKE_SOURCE_DIR}/../..")

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
