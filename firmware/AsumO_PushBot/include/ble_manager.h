#pragma once

#include <Arduino.h>

using CommandWriteHandler = void (*)(const uint8_t *data, size_t length);

/*
 *【内容】共通GATTサーバーとCOMMAND Writeハンドラを初期化します。
 *【戻り値】なし
 *【引数】handler: COMMAND CharacteristicへのWrite受信時に呼び出す処理
 */
void initializeBleManager(CommandWriteHandler handler);

/*
 *【内容】共通GATTサービスのBLEアドバタイズを開始します。
 *【戻り値】なし
 */
void startBleAdvertising();

/*
 *【内容】接続されたクライアントがいるか確認します。
 *【戻り値】接続中ならtrue
 */
bool isBleClientConnected();

/*
 *【内容】BLEアドバタイズを停止します。
 *【戻り値】なし
 */
void stopBleAdvertising();

/*
 *【内容】HEALTH Characteristicへ状態を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】batteryMillivolts: 電池電圧、health: デバイス状態、fault: 故障状態
 */
void publishBleHealth(uint16_t batteryMillivolts, uint8_t health, uint8_t fault);

/*
 *【内容】TELEMETRY CharacteristicへCdSのADC値を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】cdsLevel: CdSのADC値
 */
void publishBleTelemetry(uint16_t cdsLevel);

/*
 *【内容】RESULT Characteristicへ操作結果を設定し、接続中ならNotifyします。
 *【戻り値】なし
 *【引数】resultCode: 操作結果コード
 */
void publishBleResult(uint8_t resultCode);
