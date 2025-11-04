# ====================================================================================
# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.1.1)
set(toolchainVersion 14_2_Rel1)
set(picotoolVersion 2.1.1)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================

set(PICO_BOARD pico CACHE STRING "Board type")

cmake_minimum_required(VERSION 3.13)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

include(pico_sdk_import.cmake)

project(simple_example C CXX ASM)

# Inicializa o SDK do Pico
pico_sdk_init()

# Inclui biblioteca FatFs_SPI localizada uma pasta acima
add_subdirectory(../FatFs_SPI build)

# Adiciona o executável principal
add_executable(simple_example
    main.c          # Código principal com leitura BMP e transmissão UART
    diskio_test.c   # Teste de inicialização e comunicação SD
    bmp_reader.c    # Novo: responsável por abrir e validar imagens BMP
    hw_config.c
)

# Vincula bibliotecas necessárias
target_link_libraries(simple_example
    pico_stdlib
    FatFs_SPI
    hardware_spi
    hardware_uart
    hardware_irq   
)

# Configura nome e versão
pico_set_program_name(simple_example "simple_example")
pico_set_program_version(simple_example "0.2")

# Ativa a saída via USB (para monitor serial)
pico_enable_stdio_uart(simple_example 1)
pico_enable_stdio_usb(simple_example 1)

# Inclui diretórios de cabeçalhos
target_include_directories(simple_example PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/FatFs_SPI/ff15/source
    ${CMAKE_CURRENT_LIST_DIR}/FatFs_SPI/include
    ${CMAKE_CURRENT_LIST_DIR}/FatFs_SPI/sd_driver
)

# Gera arquivos UF2, bin, etc.
pico_add_extra_outputs(simple_example)
