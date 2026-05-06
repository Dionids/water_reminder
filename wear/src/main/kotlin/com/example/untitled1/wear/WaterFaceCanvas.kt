package com.example.untitled1.wear

import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.View
import kotlin.math.*

/**
 * Кастомный View: круглый экран заполнен водой на процент нормы.
 * Волны анимируются через постоянный invalidate на Handler.
 */
class WaterFaceCanvas @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : View(context, attrs, defStyle) {

    // --- Данные ---
    var waterPercent: Int = 70
        set(value) { field = value.coerceIn(0, 100); invalidate() }
    var currentMl: Int = 0
    var goalMl: Int = 2000

    // --- Анимация волн ---
    private var waveOffset1 = 0f
    private var waveOffset2 = 0f
    private var animatedPercent = 0f      // плавное изменение уровня воды
    private var targetPercent = 70f

    private val handler = Handler(Looper.getMainLooper())
    private val animRunnable = object : Runnable {
        override fun run() {
            waveOffset1 = (waveOffset1 + 1.2f) % (width * 2f)
            waveOffset2 = (waveOffset2 - 0.8f + width * 2f) % (width * 2f)
            // Плавное движение уровня к target
            animatedPercent += (targetPercent - animatedPercent) * 0.06f
            invalidate()
            handler.postDelayed(this, 16L) // ~60fps
        }
    }

    // --- Краски ---
    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#05080f")
    }
    private val waterBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#060c18")
    }
    private val waterFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#0e3060")
    }
    private val wave1Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#0d4080")
        alpha = 230
    }
    private val wave2Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1256a8")
        alpha = 153
    }
    private val wave3Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1a6ec4")
        alpha = 89
    }
    private val wave4Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4a9ee0")
        alpha = 30
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#0e1e3a")
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }
    private val borderInnerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1e3a6a")
        style = Paint.Style.STROKE
        strokeWidth = 1.5f
        alpha = 153
    }
    private val pctTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 72f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val mlTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#8ac4e8")
        textSize = 24f
        textAlign = Paint.Align.CENTER
    }
    private val btnCirclePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#0a2040")
    }
    private val btnBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1e4a80")
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }
    private val btnIconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#5ab4f0")
        style = Paint.Style.STROKE
        strokeWidth = 3.5f
        strokeCap = Paint.Cap.ROUND
    }

    private val clipPath = Path()
    private val wavePath = Path()

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        clipPath.reset()
        clipPath.addCircle(w / 2f, h / 2f, w / 2f, Path.Direction.CW)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = width / 2f

        canvas.save()
        canvas.clipPath(clipPath)

        // Фон
        canvas.drawCircle(cx, cy, r, bgPaint)

        // Вода: уровень снизу вверх
        val waterTop = height - (height * animatedPercent / 100f)
        val amp = if (animatedPercent > 97f) 4f else 10f

        // Базовый прямоугольник воды
        canvas.drawRect(0f, waterTop + amp, width.toFloat(), height.toFloat(), waterFillPaint)

        // 4 слоя волн
        drawWave(canvas, waterTop + 12f,  amp,       waveOffset1, wave1Paint)
        drawWave(canvas, waterTop + 6f,   amp * .75f, -waveOffset2 + width, wave2Paint)
        drawWave(canvas, waterTop + 16f,  amp * .5f,  waveOffset1 * .6f, wave3Paint)
        drawWave(canvas, waterTop + 4f,   amp * .3f, -waveOffset1 * .4f + width, wave4Paint)

        canvas.restore()

        // Кольца поверх воды (border)
        canvas.drawCircle(cx, cy, r - 3f, borderPaint)
        canvas.drawCircle(cx, cy, r - 5f, borderInnerPaint)

        // Текст процента
        val textY = cy - 20f
        pctTextPaint.color = if (waterPercent >= 100) Color.parseColor("#a0d8f8") else Color.WHITE
        canvas.drawText("${waterPercent}%", cx, textY, pctTextPaint)

        // Текст мл
        val mlStr = "${formatNum(currentMl)} мл из ${formatNum(goalMl)}"
        canvas.drawText(mlStr, cx, textY + 38f, mlTextPaint)

        // Кнопка + внизу
        val btnY = cy + r * 0.6f
        val btnR = r * 0.22f
        canvas.drawCircle(cx, btnY, btnR, btnCirclePaint)
        canvas.drawCircle(cx, btnY, btnR, btnBorderPaint)
        val iconLen = btnR * 0.55f
        canvas.drawLine(cx, btnY - iconLen, cx, btnY + iconLen, btnIconPaint)
        canvas.drawLine(cx - iconLen, btnY, cx + iconLen, btnY, btnIconPaint)
    }

    private fun drawWave(canvas: Canvas, yBase: Float, amp: Float, phase: Float, paint: Paint) {
        wavePath.reset()
        val w = width.toFloat()
        var started = false
        val step = 4f
        var x = -phase % (w * 2)
        while (x < w + step) {
            val y = yBase + sin((x / w) * Math.PI.toFloat() * 2f) * amp
            if (!started) { wavePath.moveTo(x, y); started = true }
            else wavePath.lineTo(x, y)
            x += step
        }
        wavePath.lineTo(w, height.toFloat())
        wavePath.lineTo(-phase % (w * 2), height.toFloat())
        wavePath.close()

        canvas.save()
        canvas.clipPath(clipPath)
        canvas.drawPath(wavePath, paint)
        canvas.restore()
    }

    private fun formatNum(n: Int): String {
        return if (n >= 1000) "${n / 1000} ${n % 1000}".trim() else n.toString()
    }

    fun setTarget(pct: Int) {
        targetPercent = pct.toFloat()
        waterPercent = pct
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        animatedPercent = targetPercent
        handler.post(animRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacks(animRunnable)
    }
}
