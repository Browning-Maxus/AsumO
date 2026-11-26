#include "actuator.h"

#include <ESP32Servo.h>

#include "app_config.h"

namespace {
Servo pushServo;

/*
 *【内容】サーボをニュートラル位置へ戻して電源を遮断します。
 */
void stopActuator() {
  pushServo.write(SERVO_ANGLE_NEUTRAL);
  delay(SERVO_SETTLE_MS);
  pushServo.detach();
  digitalWrite(GATE_PIN, LOW);
}
}

/*
 *【内容】サーボとハイサイドスイッチを安全な待機状態に初期化します。
 */
void initializeActuator() {
  pinMode(GATE_PIN, OUTPUT);
  digitalWrite(GATE_PIN, LOW);
}

/*
 *【内容】指定方向の物理スイッチを指定回数・時間だけ押します。
 *【戻り値】サーボ動作を完了できた場合true
 *【引数】direction: 押すスイッチ、style: 押し方
 *【備考】動作中だけGATE_PINをHIGHにし、終了時は必ずLOWに戻します。
 */
bool pressSwitch(PressDirection direction, PressStyle style) {
  const uint8_t count = style == PressStyle::DOUBLE ? 2 : 1;
  const uint16_t pressTime = style == PressStyle::LONG ? SERVO_PRESS_MS * 3 : SERVO_PRESS_MS;
  const uint8_t angle = direction == PressDirection::UP ? SERVO_ANGLE_UP : SERVO_ANGLE_DOWN;

  digitalWrite(GATE_PIN, HIGH);
  delay(20);
  pushServo.attach(SERVO_PIN);
  if (!pushServo.attached()) {
    digitalWrite(GATE_PIN, LOW);
    return false;
  }
  pushServo.write(SERVO_ANGLE_NEUTRAL);
  delay(SERVO_SETTLE_MS);
  for (uint8_t index = 0; index < count; ++index) {
    pushServo.write(angle);
    delay(pressTime);
    pushServo.write(SERVO_ANGLE_NEUTRAL);
    delay(SERVO_SETTLE_MS);
  }
  stopActuator();
  return true;
}

