package com.example.screenguard

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator

class OverlayView(
    context: Context,
    private val onUnlock: () -> Unit
) : View(context) {

    private val bgPaint = Paint().apply {
        color = Color.argb(160, 0, 0, 0)
        style = Paint.Style.FILL
    }

    private val guidePaint = Paint().apply {
        color = Color.argb(120, 255, 255, 255)
        style = Paint.Style.STROKE
        strokeWidth = 4f
        pathEffect = DashPathEffect(floatArrayOf(20f, 15f), 0f)
        isAntiAlias = true
    }

    private val guideArrowPaint = Paint().apply {
        color = Color.argb(120, 255, 255, 255)
        style = Paint.Style.FILL_AND_STROKE
        strokeWidth = 4f
        isAntiAlias = true
    }

    private val gestureTrailPaint = Paint().apply {
        color = Color.argb(200, 0, 200, 255)
        style = Paint.Style.STROKE
        strokeWidth = 8f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        isAntiAlias = true
    }

    private val textPaint = Paint().apply {
        color = Color.WHITE
        textSize = 48f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }

    private val emergencyTextPaint = Paint().apply {
        color = Color.RED
        textSize = 36f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }

    private val gestureDetector = UShapeGestureDetector()
    private val gestureTrailPath = Path()
    private var isGestureActive = false

    private var emergencyTapCount = 0
    private var lastEmergencyTapTime = 0L
    private val emergencyTimeoutMs = 5000L
    private val emergencyTapsRequired = 20
    private var emergencyTextAlpha = 255
    private val emergencyTapRegion = RectF()

    private val fadeAnimator = ValueAnimator.ofInt(255, 40).apply {
        duration = 1200
        repeatMode = ValueAnimator.REVERSE
        repeatCount = ValueAnimator.INFINITE
        interpolator = AccelerateDecelerateInterpolator()
        addUpdateListener { anim ->
            emergencyTextAlpha = anim.animatedValue as Int
            invalidate()
        }
    }

    init {
        fadeAnimator.start()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        emergencyTapRegion.set(
            w * 0.05f, h * 0.88f,
            w * 0.95f, h * 1.0f
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()

        // Background
        canvas.drawRect(0f, 0f, w, h, bgPaint)

        // Title
        textPaint.textSize = 56f
        textPaint.color = Color.WHITE
        canvas.drawText("Screen Locked", w / 2, h * 0.18f, textPaint)

        // Instruction
        textPaint.textSize = 30f
        textPaint.color = Color.argb(180, 255, 255, 255)
        canvas.drawText("Swipe in a U-shape to unlock", w / 2, h * 0.25f, textPaint)

        // U-shape guide
        drawUShapeGuide(canvas, w, h)

        // Gesture trail
        if (isGestureActive) {
            canvas.drawPath(gestureTrailPath, gestureTrailPaint)
        }

        // Emergency exit text (smooth fade)
        emergencyTextPaint.alpha = emergencyTextAlpha
        emergencyTextPaint.textSize = 24f
        canvas.drawText(
            "Tap on this text 20 times to emergency exit",
            w / 2, h * 0.93f,
            emergencyTextPaint
        )
        if (emergencyTapCount > 0) {
            emergencyTextPaint.textSize = 20f
            canvas.drawText(
                "($emergencyTapCount / $emergencyTapsRequired)",
                w / 2, h * 0.97f,
                emergencyTextPaint
            )
        }
    }

    private fun drawUShapeGuide(canvas: Canvas, w: Float, h: Float) {
        val path = Path()
        val left = w * 0.25f
        val right = w * 0.75f
        val top = h * 0.35f
        val bottom = h * 0.65f
        val radius = 40f

        path.moveTo(left, top)
        path.lineTo(left, bottom - radius)
        path.quadTo(left, bottom, left + radius, bottom)
        path.lineTo(right - radius, bottom)
        path.quadTo(right, bottom, right, bottom - radius)
        path.lineTo(right, top)

        canvas.drawPath(path, guidePaint)

        // Start arrow pointing down
        val arrow = Path().apply {
            moveTo(left - 12f, top + 10f)
            lineTo(left, top + 30f)
            lineTo(left + 12f, top + 10f)
            close()
        }
        canvas.drawPath(arrow, guideArrowPaint)

        // Labels
        textPaint.textSize = 22f
        textPaint.color = Color.argb(100, 255, 255, 255)
        canvas.drawText("START", left, top - 10f, textPaint)
        canvas.drawText("END", right, top - 10f, textPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x
        val y = event.y

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                if (emergencyTapRegion.contains(x, y)) {
                    handleEmergencyTap()
                    return true
                }
                isGestureActive = true
                gestureTrailPath.reset()
                gestureTrailPath.moveTo(x, y)
                gestureDetector.onTouchDown(x, y, width.toFloat(), height.toFloat())
                invalidate()
            }
            MotionEvent.ACTION_MOVE -> {
                if (isGestureActive) {
                    gestureTrailPath.lineTo(x, y)
                    gestureDetector.onTouchMove(x, y)
                    invalidate()
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isGestureActive) {
                    gestureDetector.onTouchUp(x, y)
                    if (gestureDetector.isUShapeComplete()) {
                        onUnlock()
                    }
                    isGestureActive = false
                    gestureTrailPath.reset()
                    gestureDetector.reset()
                    invalidate()
                }
            }
        }
        return true
    }

    private fun handleEmergencyTap() {
        val now = System.currentTimeMillis()
        if (emergencyTapCount == 0 || (now - lastEmergencyTapTime) > emergencyTimeoutMs) {
            emergencyTapCount = 1
        } else {
            emergencyTapCount++
        }
        lastEmergencyTapTime = now
        if (emergencyTapCount >= emergencyTapsRequired) {
            onUnlock()
        }
        invalidate()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        fadeAnimator.cancel()
    }
}
