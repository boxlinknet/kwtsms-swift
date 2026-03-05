# Bulk SMS

Demonstrates sending to many numbers (>200) with automatic batching.
The client splits numbers into batches of 200, waits 0.5 seconds between batches,
and retries ERR013 (queue full) with exponential backoff.
