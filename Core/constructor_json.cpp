//
//  constructor_json.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/31.
//

#include "constructor_json.hpp"
#include "cJson/cJSON.h"
#include "mxlogger_helper.hpp"
#include "logger_os.hpp"
namespace mxlogger{

std::string constructor_json::to_json(const char* name,const char* tag,const char* msg,bool  is_main_thread,int level){
    std::string timestamp =  mxlogger_helper::micros_datetime(std::chrono::system_clock::now());

        
        size_t thread_id = mxlogger::details::logger_os::thread_id();
        
        cJSON * json = cJSON_CreateObject();

        cJSON_AddStringToObject(json, "n", name);
        cJSON_AddStringToObject(json, "a", tag);
        cJSON_AddStringToObject(json, "m", msg);
        cJSON_AddBoolToObject(json, "imt", is_main_thread);
        cJSON_AddNumberToObject(json, "tid", thread_id);
        cJSON_AddNumberToObject(json,"p",level);
        
        cJSON_AddStringToObject(json, "tsp", timestamp.data());
        
        char * json_string = cJSON_PrintUnformatted(json);

        cJSON_Delete(json);
        
        strcat(json_string, "\n");
    return std::string{json_string};
}
};
