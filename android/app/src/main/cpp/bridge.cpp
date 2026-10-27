#include <jni.h>
#include <LightGBM/c_api.h>
#include <cstdint>
#include <cmath>
#include <vector>

static bool checked(JNIEnv* env, int result) {
  if (result == 0) return true;
  env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), LGBM_GetLastError());
  return false;
}
extern "C" JNIEXPORT jlong JNICALL
Java_com_example_thesis_1anxiety_NativeLgbm_load(JNIEnv* env, jobject, jstring text) {
  const char* source = env->GetStringUTFChars(text, nullptr);
  BoosterHandle handle = nullptr;
  int iterations = 0;
  int result = LGBM_BoosterLoadModelFromString(source, &iterations, &handle);
  env->ReleaseStringUTFChars(text, source);
  if (!checked(env, result)) return 0;
  return reinterpret_cast<intptr_t>(handle);
}
extern "C" JNIEXPORT jdouble JNICALL
Java_com_example_thesis_1anxiety_NativeLgbm_predict(JNIEnv* env, jobject, jlong id, jdoubleArray input) {
  const int count = env->GetArrayLength(input);
  std::vector<double> values(count);
  env->GetDoubleArrayRegion(input, 0, count, values.data());
  int64_t size = 0;
  double result = NAN;
  if (!checked(env, LGBM_BoosterPredictForMat(reinterpret_cast<void*>(id), values.data(),
      C_API_DTYPE_FLOAT64, 1, count, 1, C_API_PREDICT_NORMAL, 0, -1,
      "num_threads=1", &size, &result))) return NAN;
  if (size != 1 || !std::isfinite(result)) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), "Invalid binary model output");
    return NAN;
  }
  return result;
}
extern "C" JNIEXPORT void JNICALL
Java_com_example_thesis_1anxiety_NativeLgbm_free(JNIEnv* env, jobject, jlong id) {
  checked(env, LGBM_BoosterFree(reinterpret_cast<void*>(id)));
}
