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


 long mxlogger_util::select_log_form_path(const char* path,char* result[],long begin,int limit){
    
     std::vector<std::string> destination;
     
    long size =  select_form_path(path, &destination, begin, limit);
     
     for (int i = 0; i<destination.size(); i++) {
         std::string s = destination[i];
        
         
        const char * data = s.data();
         
         long length = strlen(data);

         result[i]=(char *)malloc(sizeof(char) * length);
         
         sprintf(result[i], "%s",data);

     }
   
    return size;
}

 int mxlogger_util::select_logfiles_dir(const char* dir,char* result[],int* length){
     std::vector<std::map<std::string, std::string>> destination;
     
     int  r =  mxlogger::get_files(&destination, dir);
     *length = (int)destination.size();
     
     for (int i = 0; i<destination.size(); i++) {
         std::map<std::string, std::string> map = destination[i];
         std::string name = map["name"];
         std::string timestamp = map["timestamp"];
         std::string size = map["size"];
         
         std::string log_info = name + "," + size + "," + timestamp;
         
         const char * data = log_info.data();
         long length = strlen(data);
         
         result[i]=(char *)malloc(sizeof(char) * length);
         
         sprintf(result[i], "%s",data);

     }
     
     return r;
}


};

}
