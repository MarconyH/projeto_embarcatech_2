add_executable(InterfaceFPGA_6
    main.c
)

# Corrige a saída para build/ em vez de build/src/
set_target_properties(InterfaceFPGA_6 PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

target_include_directories(InterfaceFPGA_6 PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}
)

target_link_libraries(InterfaceFPGA_6 
    pico_stdlib 
    hardware_uart
)

pico_add_extra_outputs(InterfaceFPGA_6)
