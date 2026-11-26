#pragma once

#include <Arduino.h>

enum class PressDirection : uint8_t { UP, DOWN };
enum class PressStyle : uint8_t { SINGLE, DOUBLE, LONG };

/*
 *【内容】サーボとハイサイドスイッチを安全な待機状態に初期化します。
 *【戻り値】なし
 */
void initializeActuator();

/*
 *【内容】指定方向の物理スイッチを指定回数・時間だけ押します。
 *【戻り値】サーボ動作を完了できた場合true
 *【引数】direction: 押すスイッチ、style: 押し方
 *【備考】動作中だけGATE_PINをHIGHにし、終了時は必ずLOWに戻します。
 */
bool pressSwitch(PressDirection direction, PressStyle style);
