//
//  flag_formatter.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#ifndef flag_formatter_hpp
#define flag_formatter_hpp

#include <stdio.h>
#include "log_msg.h"
namespace blinglog {
namespace details{
struct padding_info
{
    enum class pad_side
    {
        left,
        right,
        center
    };

    padding_info() = default;
    padding_info(size_t width, padding_info::pad_side side, bool truncate)
        : width_(width)
        , side_(side)
        , truncate_(truncate)
        , enabled_(true)
    {}

    bool enabled() const
    {
        return enabled_;
    }
    size_t width_ = 0;
    pad_side side_ = pad_side::left;
    bool truncate_ = false;
    bool enabled_ = false;
};

class flag_formatter {
public:
    explicit flag_formatter(padding_info padinfo) : padinfo_(padinfo){};
    
    flag_formatter() = default;
    virtual ~flag_formatter() = default;
    virtual void format(const details::log_msg &msg,const std::tm &tm_time,memory_buf_t &dest) = 0;
    
protected:
    padding_info padinfo_;
};

class time_formatter final : public flag_formatter{
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
private:
    memory_buf_t cached_datetime_;

};

class level_formatter final : public flag_formatter{
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
};

class message_formatter final : public flag_formatter{
    
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
};

class aggregate_formatter final : public flag_formatter{
public:
    aggregate_formatter() = default;
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
    void add_char(char ch){
        str_ += ch;
    }
    
private:
    std::string str_;
};

class tag_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
};

class prefix_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
};

class thread_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest) override;
};


}
}


#endif /* flag_formatter_hpp */
