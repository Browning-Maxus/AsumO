#pragma once

#include <Arduino.h>

constexpr char DEVICE_NAME[]                    = "Asumo PushBot";
constexpr char NVS_NAMESPACE[]                  = "pushbot";
constexpr char NVS_KEY_REGISTERED[]             = "isRegistered";
constexpr char SERVICE_UUID_REGISTRATION[]      = "262dc011-e7f0-4046-deb0-2e377e1b15be";
constexpr char CHAR_UUID_DEVICE_INFO[]          = "262dc011-e7f0-4046-deb0-2e377e1b15bf";
constexpr char SERVICE_UUID_REQUEST[]           = "c644a67a-ad5a-4d3f-ae09-2c159d99fd81";
constexpr char CHAR_UUID_HEALTH[]               = "c644a67a-ad5a-4d3f-ae09-2c159d99fd82";
constexpr char CHAR_UUID_RESULT[]               = "c644a67a-ad5a-4d3f-ae09-2c159d99fd83";
constexpr char CHAR_UUID_COMMAND[]              = "c644a67a-ad5a-4d3f-ae09-2c159d99fd84";
constexpr char CHAR_UUID_TELEMETRY[]            = "c644a67a-ad5a-4d3f-ae09-2c159d99fd85";

constexpr uint32_t DEEP_SLEEP_SECONDS           = 3;
constexpr uint32_t ROUTINE_TIMEOUT_MS           = 800;

constexpr int CDS_PIN   = 2;
constexpr int GATE_PIN  = 8;
constexpr int SERVO_PIN = 20;

constexpr uint8_t SERVO_ANGLE_UP = 0;
constexpr uint8_t SERVO_ANGLE_NEUTRAL = 30;
constexpr uint8_t SERVO_ANGLE_DOWN = 80;
constexpr uint16_t SERVO_PRESS_MS = 500;
constexpr uint16_t SERVO_SETTLE_MS = 150;
constexpr uint16_t CDS_LIT_THRESHOLD = 1800;
constexpr uint16_t BATTERY_MILLIVOLTS = 1000;
