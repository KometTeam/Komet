Pod::Spec.new do |s|
  s.name             = 'komet_tlottie'
  s.version          = '0.1.0'
  s.summary          = 'tlottie Lottie renderer for Komet.'
  s.description      = <<-DESC
Builds the tlottie C ABI with cargokit and links it into the app, where dart:ffi reaches it.
                       DESC
  s.homepage         = 'https://github.com/dkaraush/tlottie'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Komet' => 'dev@komet.pw' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust komet_tlottie',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libkomet_tlottie.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libkomet_tlottie.a',
  }
end
