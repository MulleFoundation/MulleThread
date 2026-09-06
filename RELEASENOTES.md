### 0.2.4



* thread tests use `blockUntilNoLongerBusy` for deterministic synchronization instead of fixed sleeps
* tests now reach idle via `mulleStart` / `cancelWhenIdle` and wait with `mulleJoin` instead of `cancel`+`nudge`+sleep
* join tests (`preempt`, `cancelWhenIdle`) now actually wait for thread termination

### 0.2.3

Various small improvements
