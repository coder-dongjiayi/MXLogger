//
//  mxlogger.hpp  (SPM 公开头转发 / SwiftPM public-header forwarder)
//
//  SwiftPM 要求公开头位于 target 的 include/ 目录下，且以 <MXLoggerCore/xxx.hpp> 形式被引用。
//  Core 的真实头文件保持平铺在上级目录，这里只做转发，CMake / Android / tests 不受影响。
//  SwiftPM requires public headers to live under the target's include/ directory and be
//  included as <MXLoggerCore/xxx.hpp>. The real Core headers stay flat one level up;
//  this file only forwards, so CMake / Android / tests are unaffected.
//
#ifndef MXLoggerCore_public_mxlogger_hpp
#define MXLoggerCore_public_mxlogger_hpp
#include "../../mxlogger.hpp"
#endif
