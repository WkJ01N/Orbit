#pragma once
#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <memory>
#include <functional>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateReminderMaintenanceChannel(flutter::BinaryMessenger* messenger,HWND window,std::function<void()> finish_headless);
bool ForwardReminderMaintenance();
void CompleteReminderOperation(LPARAM operation);
