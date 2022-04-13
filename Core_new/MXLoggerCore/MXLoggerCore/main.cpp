//
//  main.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include <iostream>
#include "mxlog.hpp"


int main(int argc, const char * argv[]) {
    // insert code here...
    
    const char * path = "/user/cc";
    mxlog::mxlog *l = new mxlog::mxlog(path);
    
    return 0;
}
