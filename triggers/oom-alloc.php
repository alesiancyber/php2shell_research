<?php
// Benign OOM generator for CVE-2026-109618 detection research. Logs only, no exploit.
// Sets a deliberately low memory_limit, then allocates past it so PHP emits its standard
// "Allowed memory size exhausted" fatal error. This is the observable precondition a
// detection would look for (a request driving PHP to OOM), produced the ordinary way.
ini_set('memory_limit', '32M');
$marker = 'LAB-OOM-ALLOC';   // so the request/line is easy to find
$chunks = [];
while (true) {
    $chunks[] = str_repeat('A', 1024 * 1024); // 1 MB per iteration
}
echo "unreachable $marker";
