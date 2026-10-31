// Valgrind client requests for benchmarks/check.rb, which calls them with
// Fiddle: callgrind counts the instructions between serega_start and
// serega_stop, and writes them to a new dump file. Outside Valgrind the
// requests do nothing. `rake benchmarks:check` builds it into
// tmp/callgrind.so.
#include <valgrind/callgrind.h>

int serega_on_valgrind(void) { return RUNNING_ON_VALGRIND; }

void serega_start(void) {
  CALLGRIND_START_INSTRUMENTATION;
  CALLGRIND_ZERO_STATS;
  CALLGRIND_TOGGLE_COLLECT;
}

void serega_stop(void) {
  CALLGRIND_TOGGLE_COLLECT;
  CALLGRIND_DUMP_STATS;
}
