# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

set(PICO_BOARD pico_w CACHE STRING "Board type")

# Pull in Raspberry Pi Pico SDK
include(pico_sdk_import.cmake)

# Define projeto
project(picow_freertos C CXX ASM)


#add_compile_definitions(configUSE_CORE_AFFINITY=0)

# Inicializa o pico-sdk
pico_sdk_init()

# Modify the below lines to enable/disable output over UART/USB
#pico_enable_stdio_uart(picow_freertos 0)
#pico_enable_stdio_usb(picow_freertos 1)


# Caminho para o FreeRTOS
set(FREERTOS_KERNEL_PATH ${CMAKE_CURRENT_SOURCE_DIR}/lib/FreeRTOS-Kernel)

# Importa o FreeRTOS
include(${FREERTOS_KERNEL_PATH}/portable/ThirdParty/GCC/RP2040/FreeRTOS_Kernel_import.cmake)

# Adiciona o diretório com o código modular
add_subdirectory(src)
# Add any user requested libraries
target_link_libraries(picow_freertos 
        
        )
# Modify the below lines to enable/disable output over UART/USB
pico_enable_stdio_uart(picow_freertos 0)
pico_enable_stdio_usb(picow_freertos 1)

#pico_add_extra_outputs(picow_freertos )

#pico_add_extra_outputs(picow_freertos)
