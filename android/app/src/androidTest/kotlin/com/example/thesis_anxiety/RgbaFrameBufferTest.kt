package com.example.thesis_anxiety

import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.media.Image
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageInfo
import androidx.camera.core.ImageProxy
import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer

class RgbaFrameBufferTest {
    private fun frame(width: Int, height: Int, padding: Int = 0, color: Int? = null): ImageProxy {
        val stride = width*4+padding
        val pixels = ByteBuffer.allocateDirect(stride*height)
        val colors = intArrayOf(Color.RED,Color.GREEN,Color.BLUE,Color.YELLOW)
        for (y in 0 until height) for (x in 0 until width) {
            val pixel = color ?: colors[(y*width+x)%colors.size]
            pixels.position(y*stride+x*4)
            pixels.put(Color.red(pixel).toByte()).put(Color.green(pixel).toByte()).put(Color.blue(pixel).toByte()).put(255.toByte())
        }
        pixels.position(3)
        return object : ImageProxy {
            private var crop = Rect(0,0,width,height)
            override fun getWidth() = width
            override fun getHeight() = height
            override fun getFormat() = PixelFormat.RGBA_8888
            override fun getCropRect() = crop
            override fun setCropRect(rect: Rect?) { crop = rect ?: Rect(0,0,width,height) }
            override fun getImageInfo(): ImageInfo = error("Not used by bitmap conversion")
            @ExperimentalGetImage override fun getImage(): Image? = null
            override fun getPlanes() = arrayOf(object : ImageProxy.PlaneProxy {
                override fun getBuffer() = pixels
                override fun getRowStride() = stride
                override fun getPixelStride() = 4
            })
            override fun close() {}
        }
    }

    @Test fun reusesPixelsAndWrapperResizesAndClosesWithoutChangingColors() {
        val buffer = RgbaFrameBuffer()
        try {
            val source = frame(2,2)
            val first = buffer.copy(source)
            val wrapper = buffer.image
            assertEquals(Color.YELLOW,first.getPixel(1,1))
            assertEquals(3,source.planes[0].buffer.position())
            val old = source.toBitmap()
            try { assertTrue("Same pixels as CameraX conversion",old.sameAs(first)) } finally { old.recycle() }
            val second = buffer.copy(frame(2,2,color=Color.BLUE))
            assertSame(first,second); assertSame(wrapper,buffer.image)
            assertFalse(first.isRecycled)
            assertEquals(Color.BLUE,second.getPixel(0,0))
            val resized = buffer.copy(frame(3,1,color=Color.GREEN))
            assertTrue(first.isRecycled)
            assertNotSame(first,resized)
            assertEquals(3,resized.width); assertEquals(1,resized.height)
            assertEquals(Color.GREEN,resized.getPixel(2,0))
            buffer.close()
            assertTrue(resized.isRecycled); assertNull(buffer.bitmap); assertNull(buffer.image)
        } finally { buffer.close() }
    }

    @Test fun paddedRowsUseCameraXAndLeaveTheReusableBufferAlive() {
        val buffer = RgbaFrameBuffer()
        try {
            val reusable = buffer.copy(frame(2,2))
            val fallback = buffer.copy(frame(2,2,padding=8))
            try {
                assertNotSame(reusable,fallback)
                assertEquals(Color.RED,fallback.getPixel(0,0))
                assertEquals(Color.YELLOW,fallback.getPixel(1,1))
                assertFalse(reusable.isRecycled)
                assertSame(reusable,buffer.copy(frame(2,2)))
            } finally { fallback.recycle() }
        } finally { buffer.close() }
    }
}
