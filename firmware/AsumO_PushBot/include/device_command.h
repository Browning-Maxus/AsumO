#pragma once

#include <Arduino.h>

constexpr size_t COMMAND_ID_LENGTH = 16;
constexpr size_t COMMAND_PARAMETER_MAX_LENGTH = 4;
constexpr uint8_t DEVICE_COMMAND_PUSHBOT = 0x20;

enum class Command : uint8_t {
  PING = 0x01,
  STATUS_REQUEST = 0x02,
  GET_CAPABILITIES = 0x03,
  SET_CONFIG = 0x04,
  UP = 0x20,
  DOWN = 0x21,
  DOUBLE_UP = 0x22,
  DOUBLE_DOWN = 0x23,
  LONG_UP = 0x24,
  LONG_DOWN = 0x25,
};

enum class PressStyleCode : uint8_t { SINGLE = 0x00, DOUBLE = 0x01, LONG = 0x02 };
enum class DirectionCode : uint8_t { UP = 0x00, DOWN = 0x01 };

enum class ResultCode : uint8_t {
  SUCCESS = 0x00,
  FAILED = 0x01,
  TIMEOUT = 0x02,
  LOW_BATTERY = 0x03,
  INVALID_PARAMETER = 0x04,
  NOT_SUPPORTED = 0x0F,
};
