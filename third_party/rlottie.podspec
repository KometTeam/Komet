Pod::Spec.new do |s|
  s.name             = 'rlottie'
  s.version          = '0.2.0'
  s.summary          = 'Samsung rlottie native Lottie renderer for Komet.'
  s.description      = 'Compiles the Samsung/rlottie submodule sources into the app so the native animation engine can be reached via dart:ffi (DynamicLibrary.process()).'
  s.homepage         = 'https://github.com/Samsung/rlottie'
  s.license          = { :type => 'MIT', :file => 'rlottie/COPYING' }
  s.author           = { 'Samsung Electronics' => 'opensource@samsung.com' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.requires_arc     = false

  s.source_files = [
    'rlottie/inc/*.h',
    'rlottie_build/apple/config.h',
    'rlottie/src/lottie/*.{cpp,h}',
    'rlottie/src/lottie/zip/*.{cpp,h}',
    'rlottie/src/lottie/rapidjson/**/*.h',
    'rlottie/src/vector/*.{cpp,h}',
    'rlottie/src/vector/freetype/*.{cpp,h}',
    'rlottie/src/vector/pixman/pixman-arm-neon-asm.h',
    'rlottie/src/vector/stb/*.{cpp,h}',
    'rlottie/src/binding/c/*.cpp',
  ]
  s.exclude_files = ['rlottie/src/vector/pixman/*.S']
  s.public_header_files = 'rlottie/inc/*.h'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_ENABLE_CPP_EXCEPTIONS' => 'NO',
    'GCC_ENABLE_CPP_RTTI' => 'NO',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => [
      '"${PODS_TARGET_SRCROOT}/rlottie/inc"',
      '"${PODS_TARGET_SRCROOT}/rlottie_build/apple"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/lottie"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/lottie/zip"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/lottie/rapidjson"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/vector"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/vector/freetype"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/vector/pixman"',
      '"${PODS_TARGET_SRCROOT}/rlottie/src/vector/stb"',
    ].join(' '),
  }
end
