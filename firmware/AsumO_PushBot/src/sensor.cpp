#include "sensor.h"

#include "app_config.h"

/*
 *【内容】CdSセルのADC値を複数回平均して読み取ります。
 *【戻り値】平均したADC値
 */
uint16_t readCdsLevel() {
  uint32_t total = 0;
  for (uint8_t index = 0; index < 8; ++index) {
    total += analogRead(CDS_PIN);
    delay(2);
  }
  return static_cast<uint16_t>(total / 8);
}

/*
 *【内容】CdSセルの値から電源インジケータが点灯中か判定します。
 *【戻り値】点灯中ならtrue
 */
bool isPowerIndicatorLit() {
  return readCdsLevel() >= CDS_LIT_THRESHOLD;
}
