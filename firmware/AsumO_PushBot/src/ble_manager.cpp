/* 共通GATTサーバー、Characteristic、BLE接続処理 */
#include "ble_manager.h"

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>

#include "app_config.h"

namespace {
BLECharacteristic *healthCharacteristic = nullptr;
BLECharacteristic *resultCharacteristic = nullptr;
BLECharacteristic *telemetryCharacteristic = nullptr;
CommandWriteHandler commandWriteHandler = nullptr;
volatile bool clientConnected = false;

/*
 *【内容】BLE Writeで受信した生ペイロードを16進数でシリアル出力します。
 *【戻り値】なし
 *【引数】data: 出力するバイト列、length: バイト列の長さ
 */
void printReceivedPayload(const uint8_t *data, size_t length) {
  Serial.printf("[BLE][TEST][RX] COMMAND payload (%u bytes):", static_cast<unsigned>(length));
  if (data == nullptr) {
    Serial.println(" <null>");
    return;
  }
  for (size_t index = 0; index < length; ++index) Serial.printf(" %02X", data[index]);
  Serial.println();
}

/*
 *【内容】Characteristicへバイナリ値を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】characteristic: 更新するCharacteristic、value: 設定値、length: 設定値の長さ、notify: Notifyするか
 */
void updateCharacteristic(BLECharacteristic *characteristic, const uint8_t *value, size_t length, bool notify) {
  if (characteristic == nullptr) return;
  characteristic->setValue(const_cast<uint8_t *>(value), length);
  if (notify && clientConnected) characteristic->notify();
}

/*
 *【内容】BLEサーバーの接続状態と診断ログを管理します。
 *【戻り値】なし
 */
class RoutineServerCallback : public BLEServerCallbacks {
  /*
   *【内容】Gateway接続時にアドバタイズを停止します。
   *【戻り値】なし
   *【引数】server: 接続を受けたBLEサーバー
   */
  void onConnect(BLEServer *server) override {
    clientConnected = true;
    Serial.println("[BLE][GATT] Gateway connected: waiting for COMMAND Write");
    BLEDevice::stopAdvertising();
  }

  /*
   *【内容】Gateway切断時に接続状態を解除します。
   *【戻り値】なし
   *【引数】server: 切断されたBLEサーバー
   */
  void onDisconnect(BLEServer *server) override { clientConnected = false; }

  /*
   *【内容】Gateway切断時にBLEスタックの切断理由コードを出力します。
   *【戻り値】なし
   *【引数】server: 切断されたBLEサーバー、parameter: 切断イベントの詳細
   */
  void onDisconnect(BLEServer *server, esp_ble_gatts_cb_param_t *parameter) override {
    Serial.printf("[BLE][GATT] Gateway disconnected: reason=0x%02X\n", parameter->disconnect.reason);
  }

  /*
   *【内容】GatewayがMTU交換を開始したことをテスト出力します。
   *【戻り値】なし
   *【引数】server: 接続中のBLEサーバー、parameter: MTUイベントの詳細
   */
  void onMtuChanged(BLEServer *server, esp_ble_gatts_cb_param_t *parameter) override {
    Serial.printf("[BLE][GATT] MTU exchanged: %u bytes\n", parameter->mtu.mtu);
  }
};

/*
 *【内容】COMMAND CharacteristicへのWriteを登録済みハンドラへ渡します。
 *【戻り値】なし
 */
class CommandCallback : public BLECharacteristicCallbacks {
  /*
   *【内容】Gatewayからのコマンド書き込みを受け取ります。
   *【戻り値】なし
   *【引数】characteristic: 書き込まれたCharacteristic
   */
  void onWrite(BLECharacteristic *characteristic) override {
    const std::string value = characteristic->getValue();
    const uint8_t *data = reinterpret_cast<const uint8_t *>(value.data());
    printReceivedPayload(data, value.length());
    if (commandWriteHandler != nullptr) commandWriteHandler(data, value.length());
  }
};
}

/*
 *【内容】共通GATTサーバーとCOMMAND Writeハンドラを初期化します。
 *【戻り値】なし
 *【引数】handler: COMMAND CharacteristicへのWrite受信時に呼び出す処理
 */
void initializeBleManager(CommandWriteHandler handler) {
  commandWriteHandler = handler;
  clientConnected = false;
  BLEDevice::init(DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new RoutineServerCallback());
  BLEService *service = server->createService(SERVICE_UUID_REQUEST);

  healthCharacteristic = service->createCharacteristic(CHAR_UUID_HEALTH, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  healthCharacteristic->addDescriptor(new BLE2902());
  resultCharacteristic = service->createCharacteristic(CHAR_UUID_RESULT, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  resultCharacteristic->addDescriptor(new BLE2902());
  BLECharacteristic *commandCharacteristic = service->createCharacteristic(CHAR_UUID_COMMAND, BLECharacteristic::PROPERTY_WRITE);
  commandCharacteristic->setCallbacks(new CommandCallback());
  telemetryCharacteristic = service->createCharacteristic(CHAR_UUID_TELEMETRY, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  telemetryCharacteristic->addDescriptor(new BLE2902());
  service->start();
}

/*
 *【内容】共通GATTサービスのBLEアドバタイズを開始します。
 *【戻り値】なし
 */
void startBleAdvertising() {
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID_REQUEST);
  advertising->setScanResponse(true);
  advertising->start();
  Serial.println("[BLE][ADV] Advertising started");
}

/*
 *【内容】接続されたクライアントがいるか確認します。
 *【戻り値】接続中ならtrue
 */
bool isBleClientConnected() { return clientConnected; }

/*
 *【内容】BLEアドバタイズを停止します。
 *【戻り値】なし
 */
void stopBleAdvertising() { BLEDevice::stopAdvertising(); }

/*
 *【内容】HEALTH Characteristicへ状態を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】batteryMillivolts: 電池電圧、health: デバイス状態、fault: 故障状態
 */
void publishBleHealth(uint16_t batteryMillivolts, uint8_t health, uint8_t fault) {
  const uint8_t value[] = {static_cast<uint8_t>(batteryMillivolts & 0xFF), static_cast<uint8_t>(batteryMillivolts >> 8), health, fault};
  updateCharacteristic(healthCharacteristic, value, sizeof(value), true);
}

/*
 *【内容】TELEMETRY CharacteristicへCdSのADC値を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】cdsLevel: CdSのADC値
 */
void publishBleTelemetry(uint16_t cdsLevel) {
  const uint8_t value[] = {static_cast<uint8_t>(cdsLevel & 0xFF), static_cast<uint8_t>(cdsLevel >> 8)};
  updateCharacteristic(telemetryCharacteristic, value, sizeof(value), true);
}

/*
 *【内容】RESULT Characteristicへ操作結果を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】resultCode: 操作結果コード
 */
void publishBleResult(uint8_t resultCode) {
  updateCharacteristic(resultCharacteristic, &resultCode, 1, true);
}
