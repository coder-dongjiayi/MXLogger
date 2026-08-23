Pod::Spec.new do |s|
# pod lib lint --allow-warnings --verbose --skip-import-validation
  s.name         = "MXLogger"
  s.version      = "2.0.0"
  s.summary      = "High-performance cross-platform logger built on mmap — the Objective-C API for iOS."

  s.description  = <<-DESC
                     MXLogger is a cross-platform logging library built on mmap memory
                     mapping, with AES-CFB-128 encryption. This pod is the Objective-C API
                     for iOS; the C/C++ engine lives in MXLoggerCore and is shared with the
                     Android and Flutter bindings, so log files are interchangeable across
                     platforms.

                     * mmap-backed writes: no main-thread I/O blocking, no data loss on crash
                     * Five levels (debug / info / warn / error / fatal) with a per-level
                       file-write threshold
                     * A name and comma-separated tags on every record, for filtering on read-back
                     * File split policies: yyyy_MM_dd_HH / yyyy_MM_dd / yyyy_ww / yyyy_MM
                     * Disk budget by max age and max total size, cleaned up automatically
                       when the app enters background
                     * Optional AES-CFB-128 encryption with a 16-byte key and IV
                     * Read logs back in-process, or open the .mx files with the desktop
                       mxlogger_analyzer

                     See https://github.com/coder-dongjiayi/MXLogger for full documentation.
                   DESC

  s.homepage     = "https://github.com/coder-dongjiayi/MXLogger"
  s.license      = { :type => "BSD 3-Clause", :file => "LICENSE.TXT"}
  s.author       = { "dongjiayi" => "dongjiayi" }

  s.ios.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/coder-dongjiayi/MXLogger.git", :tag => "v#{s.version}" }

  s.source_files =  "iOS/MXLogger/MXLogger", "iOS/MXLogger/MXLogger/*.{h,mm}"
  s.public_header_files = "iOS/MXLogger/MXLogger/MXLogger.h"


   s.framework    = "CoreFoundation"

   s.dependency 'MXLoggerCore', "2.0.0"
   s.libraries    = "z", "c++"
   
  s.pod_target_xcconfig = {
     'VALID_ARCHS' => 'x86_64  arm64',
    "CLANG_CXX_LANGUAGE_STANDARD" => "gnu++17",
    "CLANG_CXX_LIBRARY" => "libc++",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF" => "NO",
  }

end

