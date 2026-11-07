# The parts of a JUCE CMakeLists.txt the workflows rely on. Not a complete file: merge these into your own.
# Replace MyPlugin / MYPLUGIN with your own names.

cmake_minimum_required(VERSION 3.24)

# 1. Universal macOS binaries for macOS 11 and later. These MUST come before project(): project() creates the cache
#    entries empty and macOS then builds only for the runner's own architecture. APPLE isn't defined yet at this
#    point, so don't wrap them in if(APPLE); other platforms ignore them.
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "macOS architectures")
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")

# 2. The single source of the version. The release workflows read it from this line (the tag must be v<VERSION>), so
#    keep it in the form project(<name> VERSION x.y.z ...).
project(MyPlugin VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 3. Static MSVC runtime, so users don't need the VC++ redistributable.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# 4. Copy-after-build only for local Debug builds; CI never wants it. (CI can also force it off through
#    CMAKE_EXTRA_ARGS in packaging/plugin.env: -DMYPLUGIN_COPY_AFTER_BUILD=OFF.)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(MYPLUGIN_COPY_DEFAULT ON)
else()
    set(MYPLUGIN_COPY_DEFAULT OFF)
endif()
option(MYPLUGIN_COPY_AFTER_BUILD "Copy plugins to the user plugin folders after building" ${MYPLUGIN_COPY_DEFAULT})

include(FetchContent)
FetchContent_Declare(JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG 9.0.4 # pin a tag, so builds are reproducible and the dependency cache key is stable
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(JUCE)

# 5. Version header: cmake/BuildVersion.cmake writes generated/BuildVersion.h on every build with PLUGIN_VERSION
#    ("1.0.0"), PLUGIN_VERSION_FULL ("1.0.0" on a clean tagged commit, else "1.0.0-dev+<hash>[.dirty]") and
#    PLUGIN_DEV_BUILD (0 or 1). The workflows read PLUGIN_VERSION_FULL to name the packages; show it in your editor.
set(MYPLUGIN_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
add_custom_target(MyPluginVersion
    COMMAND ${CMAKE_COMMAND}
            -DVERSION=${PROJECT_VERSION}
            -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
            -DOUTPUT=${MYPLUGIN_GENERATED_DIR}/BuildVersion.h
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/BuildVersion.cmake
    BYPRODUCTS ${MYPLUGIN_GENERATED_DIR}/BuildVersion.h
    COMMENT "Checking build version")

# 6. AU only exists on macOS.
set(MYPLUGIN_FORMATS VST3 Standalone)
if(APPLE)
    list(APPEND MYPLUGIN_FORMATS AU)
endif()

juce_add_plugin(MyPlugin                      # -> PLUGIN_TARGET in plugin.env
    PRODUCT_NAME "My Plugin"                  # -> PRODUCT_NAME
    COMPANY_NAME "My Company"                 # -> COMPANY_NAME
    BUNDLE_ID com.mycompany.myplugin
    PLUGIN_MANUFACTURER_CODE Mnfr             # -> MANUFACTURER_CODE (four characters, at least one upper case)
    PLUGIN_CODE Mypl                          # -> PLUGIN_CODE (four characters)
    FORMATS ${MYPLUGIN_FORMATS}
    AU_MAIN_TYPE kAudioUnitType_Effect        # -> AU_TYPE aufx (kAudioUnitType_MusicDevice is aumu)
    COPY_PLUGIN_AFTER_BUILD ${MYPLUGIN_COPY_AFTER_BUILD})

target_sources(MyPlugin PRIVATE src/PluginProcessor.cpp src/PluginEditor.cpp)
target_include_directories(MyPlugin PRIVATE src ${MYPLUGIN_GENERATED_DIR})
add_dependencies(MyPlugin MyPluginVersion)

target_compile_definitions(MyPlugin PUBLIC
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(MyPlugin
    PRIVATE juce::juce_audio_utils
    PUBLIC juce::juce_recommended_config_flags juce::juce_recommended_lto_flags juce::juce_recommended_warning_flags)

# 7. Optional CLAP through clap-juce-extensions (set BUILD_CLAP=true in plugin.env). Pin a commit that matches your
#    JUCE version.
# FetchContent_Declare(clap-juce-extensions
#     GIT_REPOSITORY https://github.com/free-audio/clap-juce-extensions.git
#     GIT_TAG <commit>
#     GIT_SUBMODULES_RECURSE ON)
# FetchContent_MakeAvailable(clap-juce-extensions)
# clap_juce_extensions_plugin(TARGET MyPlugin
#     CLAP_ID "com.mycompany.myplugin"
#     CLAP_FEATURES audio-effect stereo)

# 8. Tests, registered with CTest (TEST_TARGET in plugin.env is the test executable's target). With Catch2:
#    add_executable(MyPluginTests ...), then include(Catch) and catch_discover_tests(MyPluginTests).
enable_testing()
add_subdirectory(tests)

# 9. `cmake --build --preset debug --target pluginval` validates locally, the same way CI does.
add_custom_target(pluginval
    COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/tools/run-pluginval.sh
            "$<GENEX_EVAL:$<TARGET_PROPERTY:MyPlugin_VST3,JUCE_PLUGIN_ARTEFACT_FILE>>"
    DEPENDS MyPlugin_VST3
    USES_TERMINAL)
