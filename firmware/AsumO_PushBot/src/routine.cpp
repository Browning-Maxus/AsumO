/* GatewayとのGATT通信、物理ボタン操作、DeepSleep */
#include "routine.h"

#include <Arduino.h>
#include <cstring>
#include <atomic>
#include <esp_attr.h>
#include <esp_sleep.h>

#include "actuator.h"
#include "app_config.h"
#include "ble_manager.h"
#include "device_command.h"
#include "sensor.h"

namespace {
constexpr uint32_t LAST_COMMAND_MAGIC = 0x50554243; // ASCIIでPUBC "Pushbot Command"
std::atomic<bool> transactionFinished{false};
std::atomic<bool> commandProcessing{false};

struct LastCommand {
  uint32_t magic;
  uint8_t id[COMMAND_ID_LENGTH];
  uint8_t result;
};

RTC_DATA_ATTR LastCommand lastCommand = {};

/*
 *【内容】受信したcommand_idが直前に完了した要求と同一か判定します。
 *【戻り値】同一のcommand_idならtrue
 *【引数】commandId: 判定する16バイトのcommand_id
 */
bool isDuplicateCommand(const uint8_t *commandId) {
  if (lastCommand.magic != LAST_COMMAND_MAGIC) return false;
  return memcmp(lastCommand.id, commandId, COMMAND_ID_LENGTH) == 0;
}

/*
 *【内容】完了したcommand_idと結果をRTC領域へ保存します。
 *【引数】commandId: 保存する16バイトのcommand_id、result: 実行結果
 */
void rememberCommand(const uint8_t *commandId, ResultCode result) {
  memcpy(lastCommand.id, commandId, COMMAND_ID_LENGTH);
  lastCommand.result = static_cast<uint8_t>(result);
  lastCommand.magic = LAST_COMMAND_MAGIC;
}

/*
 *【内容】command_idを16進数でシリアル出力します。
 *【戻り値】なし
 *【引数】commandId: 出力する16バイトのcommand_id
 */
void printCommandId(const uint8_t *commandId) {
  Serial.print("[BLE][COMMAND] command_id=");
  for (size_t index = 0; index < COMMAND_ID_LENGTH; ++index) Serial.printf("%02X", commandId[index]);
  Serial.println();
}

/*
 *【内容】操作結果をRESULT Characteristicへ設定してNotifyします。
 *【戻り値】なし
 *【引数】result: 操作結果
 */
void notifyResult(ResultCode result) {
  publishBleResult(static_cast<uint8_t>(result));
}

/*
 *【内容】電池、インジケータ状態、CdS生値をHEALTHとTELEMETRYへ反映します。
 *【戻り値】なし
 *【備考】HEALTHはbattery_mV(LE)、health、fault、TELEMETRYはCdS ADC値(LE)です。
 */
void publishDeviceState() {
  const uint16_t cdsLevel = readCdsLevel();
  publishBleHealth(BATTERY_MILLIVOLTS, static_cast<uint8_t>(cdsLevel >= CDS_LIT_THRESHOLD), 0x00);
  publishBleTelemetry(cdsLevel);
}

/*
 *【内容】デバイス固有の物理ボタン操作コマンドをサーボ動作へ変換します。
 *【戻り値】サーボ操作の結果
 *【引数】command: 実行するコマンド
 */
ResultCode executePressCommand(Command command) {
  PressDirection direction;
  PressStyle style = PressStyle::SINGLE;
  switch (command) {
    case Command::UP: direction = PressDirection::UP; break;
    case Command::DOWN: direction = PressDirection::DOWN; break;
    case Command::DOUBLE_UP: direction = PressDirection::UP; style = PressStyle::DOUBLE; break;
    case Command::DOUBLE_DOWN: direction = PressDirection::DOWN; style = PressStyle::DOUBLE; break;
    case Command::LONG_UP: direction = PressDirection::UP; style = PressStyle::LONG; break;
    case Command::LONG_DOWN: direction = PressDirection::DOWN; style = PressStyle::LONG; break;
    default: return ResultCode::INVALID_PARAMETER;
  }
  return pressSwitch(direction, style) ? ResultCode::SUCCESS : ResultCode::FAILED;
}

/*
 *【内容】押し方と向きのパラメータ組み合わせを検証します。
 *【戻り値】正しいPushBotパラメータならtrue
 *【引数】style: 押し方、direction: 向き
 */
bool validatePushBotAction(uint8_t style, uint8_t direction) {
  return style <= static_cast<uint8_t>(PressStyleCode::LONG) && direction <= static_cast<uint8_t>(DirectionCode::DOWN);
}

/*
 *【内容】COMMAND Characteristicへ書き込まれたcommand_id付きデータを実行します。
 *【戻り値】なし
 *【引数】data: 書き込みデータ、length: 書き込みデータ長
 *【備考】形式はcommand_id(16) + pressStyle(1) + direction(1) + reserved(2)です。
 */
void handleCommand(const uint8_t *data, size_t length) {
  commandProcessing.store(true);
  constexpr size_t pushBotPayloadLength = COMMAND_ID_LENGTH + COMMAND_PARAMETER_MAX_LENGTH;
  if (data == nullptr || length != pushBotPayloadLength) {
    Serial.printf("[BLE][COMMAND] Invalid payload length: %u (expected: %u)\n", static_cast<unsigned>(length), static_cast<unsigned>(pushBotPayloadLength));
    notifyResult(ResultCode::INVALID_PARAMETER);
    transactionFinished = true;
    commandProcessing.store(false);
    return;
  }

  const uint8_t *commandId = data;
  const uint8_t pressStyle = data[COMMAND_ID_LENGTH];
  const uint8_t direction = data[COMMAND_ID_LENGTH + 1];
  const uint8_t reserved0 = data[COMMAND_ID_LENGTH + 2];
  const uint8_t reserved1 = data[COMMAND_ID_LENGTH + 3];
  printCommandId(commandId);
  Serial.printf("[BLE][COMMAND] style=0x%02X direction=0x%02X reserved=%02X%02X\n", pressStyle, direction, reserved0, reserved1);

  if (!validatePushBotAction(pressStyle, direction)) {
    Serial.println("[BLE][COMMAND] Invalid PushBot parameters");
    notifyResult(ResultCode::INVALID_PARAMETER);
    transactionFinished = true;
    commandProcessing.store(false);
    return;
  }

  if (isDuplicateCommand(commandId)) {
    Serial.println("[BLE][COMMAND] Duplicate command_id: return cached result");
    notifyResult(static_cast<ResultCode>(lastCommand.result));
    transactionFinished = true;
    commandProcessing.store(false);
    return;
  }

  const PressDirection pressDirection = direction == static_cast<uint8_t>(DirectionCode::UP) ? PressDirection::UP : PressDirection::DOWN;
  const PressStyle style = pressStyle == static_cast<uint8_t>(PressStyleCode::SINGLE) ? PressStyle::SINGLE :
                           pressStyle == static_cast<uint8_t>(PressStyleCode::DOUBLE) ? PressStyle::DOUBLE : PressStyle::LONG;
  const ResultCode result = pressSwitch(pressDirection, style) ? ResultCode::SUCCESS : ResultCode::FAILED;
  rememberCommand(commandId, result);
  notifyResult(result);
  transactionFinished = true;
  commandProcessing.store(false);
}

/*
 *【内容】指定時間のタイマー復帰を設定してDeepSleepへ移行します。
 *【戻り値】なし
 *【引数】seconds: DeepSleep時間
 */
void enterDeepSleep(uint32_t seconds) {
  digitalWrite(GATE_PIN, LOW);
  esp_sleep_enable_timer_wakeup(static_cast<uint64_t>(seconds) * 1000000ULL);
  delay(20);
  esp_deep_sleep_start();
}
}

/*
 *【内容】共通GATTサービスを公開し、BLE要求処理後にDeepSleepへ移行します。
 *【戻り値】なし
 */
void runRoutine() {
  initializeActuator();
  transactionFinished = false;
  initializeBleManager(handleCommand);
  publishDeviceState();
  startBleAdvertising();
  const uint32_t startedAt = millis();
  while (!isBleClientConnected() && !transactionFinished && millis() - startedAt < ROUTINE_TIMEOUT_MS) delay(5);
  stopBleAdvertising();
  // 広告停止要求と並行して成立した接続イベントの処理を待ちます。
  delay(100);
  while (isBleClientConnected() && !transactionFinished) delay(5);
  // Notifyは非同期のため、Gatewayが受信して切断するまで接続を維持します。
  while (isBleClientConnected() || commandProcessing.load()) delay(5);
  enterDeepSleep(DEEP_SLEEP_SECONDS);
}
