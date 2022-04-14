//
//  main.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include <iostream>
#include "mxlogger.hpp"


int main(int argc, const char * argv[]) {
    // insert code here...
    
    const char * path = "/Users/dongjiayi/Desktop/test/";
    mxlogger::mxlogger _log(path);
    const char * name = "mxlogger";
    const char * msg = "thisismsg";
    const char * tag = "net";
    
    _log.log(0, 1, name, msg, tag, true);
    return 0;
}