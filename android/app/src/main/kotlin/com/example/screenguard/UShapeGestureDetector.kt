package com.example.screenguard

class UShapeGestureDetector {

    enum class Phase { IDLE, DESCENDING, CROSSING, ASCENDING, COMPLETE }

    private var phase = Phase.IDLE
    private var screenWidth = 0f
    private var screenHeight = 0f

    private val leftZoneMaxX = 0.35f
    private val rightZoneMinX = 0.65f
    private val topZoneMaxY = 0.45f
    private val bottomZoneMinY = 0.55f

    private var maxYReached = 0f
    private var minYAtStart = 0f
    private var minYAtEnd = Float.MAX_VALUE

    fun onTouchDown(x: Float, y: Float, width: Float, height: Float) {
        screenWidth = width
        screenHeight = height
        reset()

        if (x < screenWidth * leftZoneMaxX && y < screenHeight * topZoneMaxY) {
            phase = Phase.DESCENDING
            minYAtStart = y
            maxYReached = y
        }
    }

    fun onTouchMove(x: Float, y: Float) {
        when (phase) {
            Phase.DESCENDING -> {
                maxYReached = maxOf(maxYReached, y)
                if (y > screenHeight * bottomZoneMinY) {
                    phase = Phase.CROSSING
                }
                if (x > screenWidth * rightZoneMinX) {
                    phase = Phase.IDLE
                }
            }
            Phase.CROSSING -> {
                maxYReached = maxOf(maxYReached, y)
                if (x > screenWidth * rightZoneMinX && y > screenHeight * bottomZoneMinY) {
                    phase = Phase.ASCENDING
                    minYAtEnd = y
                }
                if (y < screenHeight * topZoneMaxY) {
                    phase = Phase.IDLE
                }
            }
            Phase.ASCENDING -> {
                minYAtEnd = minOf(minYAtEnd, y)
                if (x > screenWidth * rightZoneMinX && y < screenHeight * topZoneMaxY) {
                    val verticalTravel = maxYReached - minOf(minYAtStart, minYAtEnd)
                    if (verticalTravel > screenHeight * 0.2f) {
                        phase = Phase.COMPLETE
                    }
                }
                if (x < screenWidth * leftZoneMaxX) {
                    phase = Phase.IDLE
                }
            }
            else -> {}
        }
    }

    fun onTouchUp(x: Float, y: Float) {
        if (phase == Phase.ASCENDING &&
            x > screenWidth * rightZoneMinX &&
            y < screenHeight * topZoneMaxY
        ) {
            val verticalTravel = maxYReached - minOf(minYAtStart, minYAtEnd)
            if (verticalTravel > screenHeight * 0.2f) {
                phase = Phase.COMPLETE
            }
        }
    }

    fun isUShapeComplete(): Boolean = phase == Phase.COMPLETE

    fun reset() {
        phase = Phase.IDLE
        maxYReached = 0f
        minYAtStart = 0f
        minYAtEnd = Float.MAX_VALUE
    }
}
