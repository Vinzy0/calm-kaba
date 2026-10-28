package com.example.thesis_anxiety

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class TrackerReadersTest {
    @Test fun drainsAllReadersAfterFailureAndPreservesInterruption() {
        val failed = CompletableFuture<Unit>().apply { completeExceptionally(IllegalStateException("tracker failed")) }
        val pose = CompletableFuture<Unit>()
        val hands = CompletableFuture<Unit>()
        val entered = CountDownLatch(1); val finished = CountDownLatch(1)
        val interrupted = AtomicBoolean()
        val worker = Thread {
            Thread.currentThread().interrupt()
            entered.countDown()
            awaitTrackerReaders(listOf(failed,pose,hands))
            interrupted.set(Thread.currentThread().isInterrupted)
            finished.countDown()
        }
        worker.start()
        try {
            assertTrue(entered.await(2,TimeUnit.SECONDS))
            assertFalse("Must wait for pose and hands",finished.await(100,TimeUnit.MILLISECONDS))
            pose.complete(Unit)
            assertFalse("Must still wait for hands",finished.await(100,TimeUnit.MILLISECONDS))
            hands.complete(Unit)
            assertTrue(finished.await(2,TimeUnit.SECONDS))
            assertTrue("Restore interrupt status after draining",interrupted.get())
        } finally { pose.complete(Unit); hands.complete(Unit); worker.join(2000) }
    }
}
