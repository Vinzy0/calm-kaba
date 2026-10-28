package com.example.thesis_anxiety

import android.os.Process
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.atomic.AtomicInteger

class TrackingThreadTest {
    @Test fun setsAndroidDisplayPriorityInsideEveryWorkerThread() {
        for (name in listOf("calm-analysis","calm-face","calm-pose","calm-hands")) {
            val priority = AtomicInteger(Int.MAX_VALUE)
            val thread = trackingThreadFactory(name).newThread { priority.set(Process.getThreadPriority(Process.myTid())) }
            thread.start(); thread.join(2000)
            assertFalse("$name must finish",thread.isAlive)
            assertEquals(name,thread.name)
            assertEquals(name,Process.THREAD_PRIORITY_DISPLAY,priority.get())
        }
    }
}
