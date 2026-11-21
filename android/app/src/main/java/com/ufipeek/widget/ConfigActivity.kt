package com.ufipeek.widget

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast

class ConfigActivity : Activity() {
    private lateinit var etUrl: EditText
    private lateinit var etPassword: EditText
    private lateinit var etZte: EditText
    private lateinit var btnTest: Button
    private lateinit var tvStatus: TextView
    private lateinit var preview: FrameLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_config)
        etUrl = findViewById(R.id.et_url)
        etPassword = findViewById(R.id.et_password)
        etZte = findViewById(R.id.et_zte)
        btnTest = findViewById(R.id.btn_test)
        tvStatus = findViewById(R.id.tv_status)
        preview = findViewById(R.id.preview)

        val c = Prefs.load(this)
        etUrl.setText(c.url)
        etPassword.setText(c.password)
        etZte.setText(c.ztePassword)

        btnTest.setOnClickListener { test() }
        findViewById<Button>(R.id.btn_save).setOnClickListener { save() }

        showPreview(Prefs.lastSnapshot(this))
    }

    private fun current() = UfiConfig(
        etUrl.text.toString().trim(),
        etPassword.text.toString(),
        etZte.text.toString()
    )

    private fun save() {
        val cfg = current()
        if (!cfg.isConfigured) {
            Toast.makeText(this, "请先填写后台地址", Toast.LENGTH_SHORT).show()
            return
        }
        Prefs.save(this, cfg)
        WidgetUpdater.schedulePeriodic(this)
        WidgetUpdater.requestRefresh(this)
        Toast.makeText(this, "已保存，小组件正在刷新", Toast.LENGTH_SHORT).show()
    }

    private fun test() {
        val cfg = current()
        if (!cfg.isConfigured) {
            Toast.makeText(this, "请先填写后台地址", Toast.LENGTH_SHORT).show()
            return
        }
        btnTest.isEnabled = false
        showStatus("连接中…", R.color.secondary)
        val app = applicationContext
        Thread {
            val s = UfiClient(cfg).fetch()
            if (s.error == null) Prefs.saveSnapshot(app, s)
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                btnTest.isEnabled = true
                val error = s.error
                if (error != null) {
                    showStatus(error, R.color.error)
                } else {
                    val source = if (s.zreqOK) "zreq 自动登录" else "直接读取 goform"
                    showStatus("连接成功 · $source", R.color.success)
                }
                showPreview(s)
            }
        }.start()
    }

    private fun showStatus(message: String, color: Int) {
        tvStatus.setTextColor(getColor(color))
        tvStatus.text = message
        tvStatus.visibility = View.VISIBLE
    }

    private fun showPreview(s: UfiSnapshot?) {
        try {
            val rv = WidgetUpdater.buildMedium(this, s ?: UfiSnapshot.placeholder(), R.layout.widget_medium, false, true)
            val content = rv.apply(this, preview)
            preview.removeAllViews()
            preview.addView(content)
            findViewById<TextView>(R.id.preview_sample).visibility = if (s == null) View.VISIBLE else View.GONE
        } catch (e: Exception) {
            // 预览失败不影响使用
        }
    }
}
