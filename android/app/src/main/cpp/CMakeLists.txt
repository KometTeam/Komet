cmake_minimum_required(VERSION 3.10)

project(komet_rlottie LANGUAGES C CXX ASM)

add_subdirectory(
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/rlottie_build"
    "${CMAKE_BINARY_DIR}/rlottie")
