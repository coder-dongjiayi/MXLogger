//
//  flag_formatter.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#ifndef flag_formatter_hpp
#define flag_formatter_hpp

#include <stdio.h>
#include "log_msg.hpp"
namespace mxlogger {
namespace details{

class flag_formatter {
public:
 
    flag_formatter() = default;
    virtual ~flag_formatter() = default;
    virtual void format(const details::log_msg &msg,string &dest) = 0;

};

class time_formatter final : public flag_formatter{
public:
    void format(const details::log_msg &msg,  string &dest) override;
private:
    string cached_datetime_;

};

class level_formatter final : public flag_formatter{
public:
    void format(const details::log_msg &msg,  string &dest) override;
};

class message_formatter final : public flag_formatter{
    
public:
    void format(const details::log_msg &msg, string &dest) override;
};

class aggregate_formatter final : public flag_formatter{
public:
    aggregate_formatter() = default;
    void format(const details::log_msg &msg,  string &dest) override;
    void add_char(char ch){
        str_ += ch;
    }
    
private:
    std::string str_;
};

class tag_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg,  string &dest) override;
};

class prefix_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg,  string &dest) override;
};

class thread_formatter final: public flag_formatter{
public:
    void format(const details::log_msg &msg, string &dest) override;
};


}
}


#endif /* flag_formatter_hpp */
