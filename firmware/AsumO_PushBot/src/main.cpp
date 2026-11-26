#include <Arduino.h>

#include "registration.h"
#include "routine.h"

/*
 *【内容】登録済みなら通常運転、未登録なら登録用BLEアドバタイズを開始します。
 *【戻り値】なし
 */
void setup() {
  Serial.begin(115200);
  delay(4000);
  
  if (isDeviceRegistered()) {
    runRoutine();
  }

  runRegistrationMode();
}

/*
 *【内容】Arduinoランタイムのループを維持します。
 *【戻り値】なし
 */
void loop() {
  delay(1000);
}
