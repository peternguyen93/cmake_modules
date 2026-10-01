function(include_all_modules root_dir pattern)
    file(GLOB_RECURSE module_files
        CONFIGURE_DEPENDS
        "${root_dir}/${pattern}"
    )

    list(SORT module_files)

    foreach(module ${module_files})
        message(STATUS "Including module: ${module}")
        include(${module})
    endforeach()
endfunction()

function(swift_build_library TARGET PATH CONFIG)

    find_program(SWIFT_EXECUTABLE swift REQUIRED)

    # ------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------

    if(NOT CONFIG)
        if(CMAKE_BUILD_TYPE)
            set(CONFIG "${CMAKE_BUILD_TYPE}")
        else()
            set(CONFIG Debug)
        endif()
    endif()

    string(TOLOWER "${CONFIG}" SWIFT_CONFIG)

    if(SWIFT_CONFIG STREQUAL "debug")
        set(SWIFT_CONFIG_NAME "Debug")
    elseif(SWIFT_CONFIG STREQUAL "release")
        set(SWIFT_CONFIG_NAME "Release")
    else()
        message(FATAL_ERROR
            "Unsupported Swift configuration: ${CONFIG}. "
            "Expected Debug or Release."
        )
    endif()


    # ------------------------------------------------------------
    # Apple deployment target
    # ------------------------------------------------------------

    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        message(FATAL_ERROR
            "CMAKE_OSX_DEPLOYMENT_TARGET is not set"
        )
    endif()

    # ------------------------------------------------------------
    # Architecture
    # ------------------------------------------------------------

    list(LENGTH CMAKE_OSX_ARCHITECTURES ARCH_COUNT)

    if(NOT ARCH_COUNT EQUAL 1)
        message(FATAL_ERROR
            "Swift build currently expects exactly one "
            "CMAKE_OSX_ARCHITECTURES"
        )
    endif()

    list(GET CMAKE_OSX_ARCHITECTURES 0 SWIFT_ARCH)


    # ------------------------------------------------------------
    # Swift triple
    # ------------------------------------------------------------

	# ------------------------------------------------------------
    # Determine Swift platform from sysroot
    # ------------------------------------------------------------
	
    if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
		set(SWIFT_PLATFORM "ios")

	elseif(CMAKE_SYSTEM_NAME STREQUAL "iOSSimulator")
		set(SWIFT_PLATFORM "ios-simulator")

	elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
		set(SWIFT_PLATFORM "macosx")

	else()
		message(FATAL_ERROR
			"Unsupported CMake system: ${CMAKE_SYSTEM_NAME}"
		)
	endif()

    set(SWIFT_TRIPLE
        "${SWIFT_ARCH}-apple-${SWIFT_PLATFORM}${CMAKE_OSX_DEPLOYMENT_TARGET}"
    )

    # ------------------------------------------------------------
    # Paths
    # ------------------------------------------------------------

    set(SWIFT_BUILD_DIR
        "${CMAKE_CURRENT_BINARY_DIR}/swift-build/${TARGET}"
    )

	if(SWIFT_PLATFORM STREQUAL "ios")
		set(SWIFT_LIBRARY
			"${SWIFT_BUILD_DIR}/out/Products/${SWIFT_CONFIG_NAME}-iphoneos/lib${TARGET}.a"
		)
	else()
		set(SWIFT_LIBRARY
			"${SWIFT_BUILD_DIR}/out/Products/${SWIFT_CONFIG_NAME}/lib${TARGET}.a"
		)
	endif()

    set(SWIFT_STAMP
        "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-swift.stamp"
    )


    # ------------------------------------------------------------
    # Diagnostics
    # ------------------------------------------------------------

    message(STATUS "Swift target       : ${TARGET}")
    message(STATUS "Swift configuration: ${SWIFT_CONFIG}")
    message(STATUS "Swift product      : ${SWIFT_CONFIG_NAME}")
    message(STATUS "Swift sysroot      : ${CMAKE_OSX_SYSROOT}")
    message(STATUS "Swift platform     : ${SWIFT_PLATFORM}")
    message(STATUS "Swift architecture : ${SWIFT_ARCH}")
    message(STATUS "Swift deployment   : ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    message(STATUS "Swift triple       : ${SWIFT_TRIPLE}")
    message(STATUS "Swift library      : ${SWIFT_LIBRARY}")


    # ------------------------------------------------------------
    # Build
    # ------------------------------------------------------------

    add_custom_command(
        OUTPUT
            "${SWIFT_STAMP}"

        COMMAND
            "${CMAKE_COMMAND}" -E make_directory
            "${SWIFT_BUILD_DIR}"

        COMMAND
            "${SWIFT_EXECUTABLE}"
            build
            --package-path "${PATH}"
			--scratch-path "${SWIFT_BUILD_DIR}"
			--configuration "${SWIFT_CONFIG}"
			--triple "${SWIFT_TRIPLE}"
			--sdk "${CMAKE_OSX_SYSROOT}"

        COMMAND
            "${CMAKE_COMMAND}" -E touch
            "${SWIFT_STAMP}"

        DEPENDS
            "${PATH}/Package.swift"

        WORKING_DIRECTORY
            "${PATH}"

        COMMENT
            "Building Swift target ${TARGET} (${SWIFT_CONFIG})"

        VERBATIM
    )

    add_custom_target(
        "${TARGET}-swift"
        DEPENDS
            "${SWIFT_STAMP}"
    )

    set("${TARGET}_SWIFT_LIBRARY"
        "${SWIFT_LIBRARY}"
        PARENT_SCOPE
    )

    set("${TARGET}_SWIFT_TARGET"
        "${TARGET}-swift"
        PARENT_SCOPE
    )

endfunction()

function(libtool_merge TARGET OUTPUT)

    set(INPUTS ${ARGN})

    if(NOT INPUTS)
        message(FATAL_ERROR
            "libtool_merge(${TARGET}): no input libraries"
        )
    endif()

    add_custom_command(
        OUTPUT
            "${OUTPUT}"

        COMMAND
            /usr/bin/libtool
            -static
            -o
            "${OUTPUT}.tmp"
            ${INPUTS}

        COMMAND
            "${CMAKE_COMMAND}"
            -E
            copy
            "${OUTPUT}.tmp"
            "${OUTPUT}"

        COMMAND
            "${CMAKE_COMMAND}"
            -E
            remove
            "${OUTPUT}.tmp"

        DEPENDS
            ${INPUTS}

        COMMENT
            "Merging static library ${TARGET}"

        VERBATIM
    )

    add_custom_target(
        "${TARGET}"
        DEPENDS
            "${OUTPUT}"
    )

    set(
        "${TARGET}_LIBRARY"
        "${OUTPUT}"
        PARENT_SCOPE
    )

endfunction()