#import <Foundation/Foundation.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void MXPStart(uint32_t stride, uint32_t offset);
void MXPRecordBegin(uint64_t index);
void MXPMessageBegin(void);
void MXPMessageEnd(void);
void MXPRecordEnd(void);
const char* _Nonnull MXPFinishJSON(void);
bool MXPInstrumented(void);
NSString* _Nonnull MXPCoreVersion(void);
void MXPFlushLogger(NSString* _Nonnull token);
NSDictionary* _Nonnull MXPResources(void);
NSDictionary* _Nonnull MXPCoreRun(NSString* _Nonnull directory,
    NSArray<NSString*>* _Nonnull messages, BOOL encrypted);
#ifdef __cplusplus
}
#endif
