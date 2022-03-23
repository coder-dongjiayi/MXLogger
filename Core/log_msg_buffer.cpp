//
//  log_msg_buffer.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/16.
//

#include "log_msg_buffer.hpp"

namespace mxlogger {
namespace details {

 log_msg_buffer::log_msg_buffer(const log_msg &orig_msg)
    : log_msg{orig_msg}
{
    buffer.append(prefix.begin(), prefix.end());
    buffer.append(tag.begin(), tag.end());
    buffer.append(payload.begin(), payload.end());
    update_string_views();
}

 log_msg_buffer::log_msg_buffer(const log_msg_buffer &other)
    : log_msg{other}
{
    buffer.append(prefix.begin(), prefix.end());
    buffer.append(tag.begin(), tag.end());
    buffer.append(payload.begin(), payload.end());
    update_string_views();
}

 log_msg_buffer::log_msg_buffer(log_msg_buffer &&other) noexcept : log_msg{other}, buffer{std::move(other.buffer)}
{
    update_string_views();
}

 log_msg_buffer &log_msg_buffer::operator=(const log_msg_buffer &other)
{
    log_msg::operator=(other);
    buffer.clear();
    buffer.append(other.buffer.data(), other.buffer.data() + other.buffer.size());
    update_string_views();
    return *this;
}

 log_msg_buffer &log_msg_buffer::operator=(log_msg_buffer &&other) noexcept
{
    log_msg::operator=(other);
    buffer = std::move(other.buffer);
    update_string_views();
    return *this;
}

 void log_msg_buffer::update_string_views()
{
    prefix = string_view_t{prefix.data(), prefix.size()};
    tag = string_view_t{tag.data(), tag.size()};
    payload = string_view_t{buffer.data() + prefix.size() + tag.size(), payload.size()};
}

}
}
