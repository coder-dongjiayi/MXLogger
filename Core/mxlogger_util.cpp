//
//  mxlogger_util.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/7.
//

#include "mxlogger_util.hpp"
#include "mxlogger_file_util.hpp"
namespace mxlogger{
namespace util{


 long mxlogger_util::select_log_form_path(const char* path,std::vector<std::string> *destination){
    
     
    long size =  select_form_path(path, destination);
     

   
    return size;
}

 int mxlogger_util::select_logfiles_dir(const char* dir,std::vector<std::map<std::string, std::string>> *destination){
    
     
     int  r =  mxlogger::get_files(destination, dir);
 
    
     return r;
}


};

}
