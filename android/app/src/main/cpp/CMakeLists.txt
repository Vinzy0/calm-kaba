cmake_minimum_required(VERSION 3.22.1)
project(calm_inference LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set_property(GLOBAL PROPERTY JOB_POOLS calm_compile=2)
set(CMAKE_JOB_POOL_COMPILE calm_compile)

# Pinned upstream 4.7.0 sources, no model conversion and no OpenMP runtime.
# setup_native.ps1 downloads them; this small build also supports JVM parity tests.
set(LGBM "${CMAKE_CURRENT_SOURCE_DIR}/LightGBM")
enable_language(C)
set(NANOARROW_DEBUG_EXTRA_WARNINGS OFF CACHE BOOL "Upstream debug warnings include 32-bit Arrow conversions" FORCE)
add_subdirectory("${LGBM}/external_libs/nanoarrow" nanoarrow EXCLUDE_FROM_ALL)
file(GLOB LGBM_SOURCES
  "${LGBM}/src/boosting/*.cpp" "${LGBM}/src/io/*.cpp"
  "${LGBM}/src/metric/*.cpp" "${LGBM}/src/network/*.cpp"
  "${LGBM}/src/objective/*.cpp" "${LGBM}/src/treelearner/*.cpp"
  "${LGBM}/src/utils/*.cpp")
add_library(calm_lgbm SHARED bridge.cpp "${LGBM}/src/c_api.cpp" ${LGBM_SOURCES})
target_link_libraries(calm_lgbm PRIVATE nanoarrow_static)
target_include_directories(calm_lgbm PRIVATE "${LGBM}/include" "${LGBM}/external_libs/eigen"
  "${LGBM}/external_libs/fast_double_parser/include" "${LGBM}/external_libs/fmt/include"
  "${LGBM}/external_libs")
target_compile_definitions(calm_lgbm PRIVATE EIGEN_MPL2_ONLY EIGEN_DONT_PARALLELIZE USE_SOCKET)
if(ANDROID)
  if(ANDROID_ABI STREQUAL "x86_64")
    # Match upstream's mm_malloc header probe on the emulator architecture.
    target_compile_definitions(calm_lgbm PRIVATE MM_MALLOC=1)
  endif()
  target_link_libraries(calm_lgbm PRIVATE log)
  target_link_options(calm_lgbm PRIVATE "-Wl,-z,max-page-size=16384")
else()
  find_package(JNI REQUIRED)
  target_include_directories(calm_lgbm PRIVATE ${JNI_INCLUDE_DIRS})
endif()
if(MSVC)
  # JBR bundles the older MSVC runtime; use its mutex initialization ABI in
  # the C API translation unit used by the host-only parity runner.
  set_source_files_properties("${LGBM}/src/c_api.cpp"
    PROPERTIES COMPILE_DEFINITIONS _DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)
  set_source_files_properties("${LGBM}/src/network/linkers_socket.cpp" "${LGBM}/src/network/network.cpp"
    PROPERTIES COMPILE_DEFINITIONS WIN_HAS_INET_PTON)
  target_link_libraries(calm_lgbm PRIVATE ws2_32)
  target_compile_options(calm_lgbm PRIVATE /bigobj /utf-8 /MP2)
  target_compile_definitions(calm_lgbm PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
else()
  target_compile_options(calm_lgbm PRIVATE -O2 -g0 -Wno-unknown-pragmas)
endif()
