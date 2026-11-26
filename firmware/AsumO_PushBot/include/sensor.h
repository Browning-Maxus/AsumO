#pragma once

#include <Arduino.h>

/*
 *【内容】CdSセルのADC値を複数回平均して読み取ります。
 *【戻り値】平均したADC値
 */
uint16_t readCdsLevel();

/*
 *【内容】CdSセルの値から電源インジケータが点灯中か判定します。
 *【戻り値】点灯中ならtrue
 */
bool isPowerIndicatorLit();
