cmake_minimum_required( VERSION 3.10 )

project( rlottie VERSION 0.2 LANGUAGES C CXX ASM )

set(RLOTTIE "${CMAKE_CURRENT_LIST_DIR}/../rlottie")

if (NOT EXISTS "${RLOTTIE}/src/CMakeLists.txt")
    message(FATAL_ERROR
        "rlottie submodule is missing. Run: git submodule update --init --recursive")
endif()

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

if (NOT DEFINED BUILD_SHARED_LIBS)
    set(BUILD_SHARED_LIBS ON)
endif()

add_library( rlottie )
set_target_properties( rlottie PROPERTIES DEFINE_SYMBOL RLOTTIE_BUILD )

set(LOTTIE_MODULE OFF)
set(LOTTIE_THREAD ON)
set(LOTTIE_CACHE ON)
set(LOTTIE_MODULE_PATH "")

configure_file(${RLOTTIE}/cmake/config.h.in config.h)

target_include_directories(rlottie
    PUBLIC $<BUILD_INTERFACE:${RLOTTIE}/inc>
    PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
    )

if(MSVC)
    target_compile_options(rlottie
                        PRIVATE
                            /std:c++14
                            /EHs-c-
                            /GR-
                            /W3
                        )
else()
    target_compile_options(rlottie
                        PRIVATE
                            -std=c++14
                            -fno-exceptions
                            -fno-unwind-tables
                            -fno-asynchronous-unwind-tables
                            -fno-rtti
                            -Wall
                            -fvisibility=hidden
                            -Wnon-virtual-dtor
                            -Woverloaded-virtual
                            -Wno-unused-parameter
                        )
endif()

if (WIN32 AND NOT BUILD_SHARED_LIBS)
    target_compile_definitions(rlottie PUBLIC -DRLOTTIE_BUILD=0)
endif()

set( CMAKE_THREAD_PREFER_PTHREAD TRUE )
find_package( Threads )

if(WIN32)
   set( OSSPEC_LIBS Shlwapi.lib )
endif()

target_link_libraries(rlottie
                    PUBLIC
                        "${CMAKE_THREAD_LIBS_INIT}"
                        ${OSSPEC_LIBS}
                     )

if (CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a"
    OR CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|armv7)")
    target_compile_options(rlottie PRIVATE -U__ARM_NEON__)
endif()

add_subdirectory(${RLOTTIE}/src "${CMAKE_CURRENT_BINARY_DIR}/rlottie_src")
