#ifndef _driver_H_
#define _driver_H_

#include <cstdio>
#include "map.h"
#include "chpl.h"

extern FILE* html_index_file;

extern Map<const char*, const char*> configParamMap;

extern int instantiation_limit;

extern int fdump_html;

extern int trace_level;

// whether to enable insertion of destructor calls when variables go out of scope
// disabled if a begin statement has been encountered in the program being compiled
extern bool fEnableDestructorCalls;

// optimization control flags
extern bool fNoBoundsChecks;
extern bool fNoCopyPropagation;
extern bool fNoDeadCodeElimination;
extern bool fNoInlineIterators;
extern bool fNoInline;
extern bool fNoLiveAnalysis;
extern bool fNoLocalChecks;
extern bool fNoNilChecks;
extern bool fNoRemoteValueForwarding;
extern bool fNoScalarReplacement;
extern bool fNoOptimizeLoopIterators;
extern bool fNoPrivatization;

extern bool report_inlining;
extern char CHPL_HOME[FILENAME_MAX];

extern const char* CHPL_HOST_PLATFORM;
extern const char* CHPL_TARGET_PLATFORM;
extern const char* CHPL_HOST_COMPILER;
extern const char* CHPL_TARGET_COMPILER;
extern const char* CHPL_THREADS;
extern const char* CHPL_COMM;

extern char chplmake[256];
extern char fExplainCall[256];
extern char fExplainInstantiation[256];

extern char fPrintStatistics[256];
extern bool fPrintDispatch;
extern bool fGenIDS;
extern bool fSerialForall;
extern bool fSerial;
extern bool fLocal;
extern bool fieeefloat;

extern int debugParserLevel;
extern bool fRuntime;
extern bool no_codegen;
extern bool developer;
extern int num_constants_per_variable;
extern bool printCppLineno;

extern char defaultDist[256];
extern char mainModuleName[256];
extern bool ignore_warnings;
extern bool ignore_errors;
extern int squelch_header_errors;

extern bool fWarnPromotion;

extern bool debugCCode, optimizeCCode;

extern bool fEnableTimers;
extern Timer timer1;
extern Timer timer2;
extern Timer timer3;
extern Timer timer4;
extern Timer timer5;

extern int numGlobalsOnHeap;

// code generation strings
extern const char* compileCommand;
extern char compileVersion[64];


#endif
