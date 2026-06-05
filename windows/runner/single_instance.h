#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

// Returns true if this process acquired the single-instance mutex.
// Returns false if another Orbit instance is already running.
bool AcquireSingleInstanceMutex();

// Notifies an existing Orbit window to restore and come to the foreground.
// Returns true if an existing window was found and notified.
bool ActivateExistingInstance();

// Registered window message used to activate an existing instance.
unsigned int GetShowExistingInstanceMessage();

#endif  // RUNNER_SINGLE_INSTANCE_H_
