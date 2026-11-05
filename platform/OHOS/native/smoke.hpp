#pragma once
#include <string>

namespace mxlogger_poc {
// A serialized, synchronous probe only. This is not the public OHOS SDK API.
__attribute__((visibility("default"))) std::string run(const std::string &directory, bool encrypted);
}
