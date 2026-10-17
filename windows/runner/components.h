#pragma once
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <memory>
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> CreateComponentChannel(flutter::FlutterEngine* engine);
