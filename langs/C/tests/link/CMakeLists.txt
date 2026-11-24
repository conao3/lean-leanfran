cmake_minimum_required(VERSION 3.16)
project(LeanfranCConsumer LANGUAGES C)

find_package(public_api CONFIG REQUIRED)
add_executable(consumer main.c)
set_target_properties(consumer PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED YES)
target_link_libraries(consumer PRIVATE public_api::public_api)
