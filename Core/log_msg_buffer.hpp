//
//  log_msg_buffer.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/16.
//

#ifndef log_msg_buffer_hpp
#define log_msg_buffer_hpp

#include <stdio.h>
#include "log_msg.h"
namespace mxlogger {
namespace details {


class  log_msg_buffer : public log_msg
{
    memory_buf_t buffer;
    void update_string_views();

public:
    log_msg_buffer() = default;
    explicit log_msg_buffer(const log_msg &orig_msg);
    log_msg_buffer(const log_msg_buffer &other);
    log_msg_buffer(log_msg_buffer &&other) noexcept;
    log_msg_buffer &operator=(const log_msg_buffer &other);
    log_msg_buffer &operator=(log_msg_buffer &&other) noexcept;
};

}
}

#endif /* log_msg_buffer_hpp */
