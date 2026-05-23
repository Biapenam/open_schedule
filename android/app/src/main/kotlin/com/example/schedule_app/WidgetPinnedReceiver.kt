package com.example.schedule_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

class WidgetPinnedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.i("OpenScheduleWidget", "Widget pin callback received")
        Toast.makeText(context, "桌面小卡片已添加", Toast.LENGTH_SHORT).show()
    }
}
