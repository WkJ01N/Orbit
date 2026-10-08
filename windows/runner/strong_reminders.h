#pragma once
#include <string>
std::string StrongCommand(const std::string& command,const std::string& argument="");
void OpenStrongReminder();
int RunStrongReminderWorker();

int RunStrongReminderSelfTest();
