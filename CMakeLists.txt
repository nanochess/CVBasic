cmake_minimum_required(VERSION 3.13)

project(cvbasic C)

set(CMAKE_C_STANDARD 11)

add_executable(${PROJECT_NAME} cvbasic.c node.c driver.c cpuz80.c cpu6502.c cpu9900.c)