//
//  mmap_sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#ifndef mmap_sink_hpp
#define mmap_sink_hpp

#include <stdio.h>
#include "memory_mmap.hpp"
#include "log_msg.hpp"
#include "sink.hpp"
namespace mxlogger{
namespace sinks {
class mmap_sink : public sink{
public:
    
    mmap_sink(const std::string &dir_path,policy::storage_policy policy);
    
    ~mmap_sink(){};
    
    void log(const details::log_msg &msg) override;
    void flush() override;

private:
    std::atomic_int level_{level::debug};
    
    std::shared_ptr<memory_mmap> mmap_;
    std::string filename_;
    
   
    void handle_date_(policy::storage_policy policy);
};



}
}
#endif /* mmap_sink_hpp */
