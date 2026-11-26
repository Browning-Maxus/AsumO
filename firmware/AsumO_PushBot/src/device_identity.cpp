/* ========================================================================== */
/*                デバイスの情報をGatewayやアプリとやりとりをする             */
/* ========================================================================== */

#include "device_identity.h"
#include "app_config.h"

#include <esp_mac.h>

/*
 *【内容】BLE MACアドレスを個体識別用文字列として取得します。
 *【戻り値】BLE MACアドレス
 */
String getBleMacAddress() {
  uint8_t mac[6] = {};
  if (esp_read_mac(mac, ESP_MAC_BT) != ESP_OK) return "00:00:00:00:00:00";

  char text[18] = {};
  snprintf(text, sizeof(text), "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(text);
}

/*
 *【内容】アプリ登録時に送信するJSONを作成します。
 *【戻り値】登録情報JSON
 */
String makeRegistrationJson() {
  return String("{\"service_uuid\":\"") + SERVICE_UUID_REGISTRATION +
         "\",\"id\":\"" + getBleMacAddress() +
         "\",\"battery\":100,"
         "\"icon\":\"\",\"name\":\"" + DEVICE_NAME +
         "\",\"reservation\":[]}";
}