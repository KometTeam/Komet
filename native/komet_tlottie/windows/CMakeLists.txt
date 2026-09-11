cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "komet_tlottie")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust komet_tlottie "")

set(komet_tlottie_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
