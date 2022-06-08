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
    
    mmap_sink(const std::string &dir_path,policy::storage_policy policy,const std::string &file_name);
    
    ~mmap_sink(){};
    
    void log(const details::log_msg &msg) override;
    void flush() override;

private:
  
    
    
    std::shared_ptr<memory_mmap> mmap_;
    
};



}
}
#endif /* mmap_sink_hpp */
