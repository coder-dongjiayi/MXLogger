//
//  file_sink.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/5.
//

#include "file_sink.hpp"

namespace blinglog{
namespace sinks{

file_sink::file_sink(): formatter_(make_unique<pattern_formatter>()){
  
    
}

void file_sink::set_file_name(const std::string &filename){
    std::lock_guard<std::mutex> lock(mutex_t);
    file_appender_.set_filename(filename);
}
void file_sink::set_file_policy(policy::storage_policy policy){
    std::lock_guard<std::mutex> lock(mutex_t);
    
    file_appender_.set_policy(policy);
    
}
long long file_sink::file_size() const{
    std::lock_guard<std::mutex> lock(mutex_t);
    return  file_helper_.file_size();
}
// 文件最大存储时间 默认为0 不限制
void file_sink::set_file_max_disk_age(long long max_age){
    file_helper_.set_max_disk_age(max_age);
}

// 文件最大存储大小 默认为0 不限制
void file_sink::set_file_max_disk_size(long long max_size){
    file_helper_.set_max_disk_size(max_size);
}
void file_sink::remove_all(){
    file_helper_.remove_all();
}

void file_sink::remove_expire_data(){
    file_helper_.remove_expire_data();
}
void file_sink::set_filedir(const std::string &filedir){
    std::lock_guard<std::mutex> lock(mutex_t);
   
    file_helper_.set_dir(filedir);
    
   
}
void file_sink::set_file_header(const std::string &header){
    std::lock_guard<std::mutex> lock(mutex_t);
    memory_buf_t formatted;

    details::fmt_helper::append_string_view(string_view_t{header}, formatted);

    details::fmt_helper::append_string_view(default_eol, formatted);

    file_helper_.set_header(formatted);
    
    file_helper_.remove_expire_data();
    
}
void file_sink::log(const details::log_msg &msg){
    std::lock_guard<std::mutex> lock(mutex_t);
    memory_buf_t formatted;
    formatter_->format(msg, formatted);
   
    memory_buf_t filename;
  
    
    file_helper_.write(formatted,file_appender_.calc_filename());
    
    file_helper_.flush();
}

void file_sink::set_pattern(const std::string &pattern){
    // 构建fommater
    formatter_ = std::unique_ptr<blinglog::formatter>(new pattern_formatter(pattern));
};

void file_sink::flush(){
    file_helper_.flush();
}



}
}
