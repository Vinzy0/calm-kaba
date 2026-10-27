package com.example.thesis_anxiety

object NativeLgbm {
    init { System.loadLibrary("calm_lgbm") }
    external fun load(text: String): Long
    external fun predict(handle: Long, features: DoubleArray): Double
    external fun free(handle: Long)
}
