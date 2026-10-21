<?php
// Reports the FastCGI worker pid, to show whether the same worker is reused across requests
// (the cross-request condition the use-after-free needs). Benign.
echo "LAB-PID=" . getmypid();
