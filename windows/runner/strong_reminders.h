#pragma once
#include <string>
std::string StrongCommand(const std::string& command,const std::string& argument="");
void OpenStrongReminder();
int RunStrongReminderWorker();

int RunStrongReminderSelfTest();

void RegisterStrongReminderWindow(void* window);

void SetStrongReminderTestState(const std::wstring& path);
int RunStrongReminderOSSelfTest(const std::wstring& path);
