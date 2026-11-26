/* ========================================================================== */
/*                  デバイスをアプリ及びAWSに保存します。                     */
/* ========================================================================== */
#include "registration.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <Preferences.h>

#include "app_config.h"
#include "device_identity.h"

namespace {
class RegistrationCallback : public BLECharacteristicCallbacks {
  /*
   *【内容】初回限定。アプリからの登録完了通知を受けてNVSへ登録状態を保存します。
   *【引数】characteristic: 書き込まれたCharacteristic
   */
  void onWrite(BLECharacteristic *characteristic) override {
    Serial.printf("Registration acknowledgement: %s\n", characteristic->getValue().c_str());
    markDeviceRegistered();
  }
};
}

/*
 *【内容】NVSに保存したアプリ登録済みフラグを読み取ります。
 *【戻り値】登録済みならtrue
 */
bool isDeviceRegistered() {
  Preferences preferences;
  if (!preferences.begin(NVS_NAMESPACE, true)) return false;
  const bool registered = preferences.getBool(NVS_KEY_REGISTERED, false);
  preferences.end();
  return registered;
}

/*
 *【内容】アプリ登録の完了をNVSに保存します。
 *【戻り値】なし
 */
void markDeviceRegistered() {
  Preferences preferences;
  if (!preferences.begin(NVS_NAMESPACE, false)) {
    Serial.println("Failed to open NVS for registration update.");
    return;
  }
  preferences.putBool(NVS_KEY_REGISTERED, true);
  preferences.end();
  Serial.println("Registration persisted to NVS.");
}

/*
 *【内容】アプリ登録用BLEサービスを開始します。
 *【戻り値】なし
 */
void runRegistrationMode() {
  BLEDevice::init(DEVICE_NAME);

  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(SERVICE_UUID_REGISTRATION);

  BLECharacteristic *deviceInfo = service->createCharacteristic(
    CHAR_UUID_DEVICE_INFO, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  deviceInfo->setValue(makeRegistrationJson().c_str());
  deviceInfo->setCallbacks(new RegistrationCallback());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID_REGISTRATION);
  advertising->setScanResponse(true);
  advertising->start();
}
