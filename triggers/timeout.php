<?php
// Benign timeout generator for CVE-2026-109619 detection research. Logs only, no exploit.
// Runs past max_execution_time so PHP emits its "Maximum execution time exceeded" fatal,
// one of the two interrupting fatals the advisory names (the other, OOM, is CVE-2026-109618).
set_time_limit(2);
$x = 0;
while (true) { $x++; }   // busy loop: trips the executor's time check
echo "unreachable";
