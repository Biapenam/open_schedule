package com.example.schedule_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget_layout)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            // home_widget 0.6.0 writes saveWidgetData values here.
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences",
                Context.MODE_PRIVATE
            )

            // 日期显示
            val cal = Calendar.getInstance()
            val todayJavaWeekday = cal.get(Calendar.DAY_OF_WEEK)
            val flutterWeekday = when (todayJavaWeekday) {
                Calendar.MONDAY    -> 1
                Calendar.TUESDAY   -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY  -> 4
                Calendar.FRIDAY    -> 5
                Calendar.SATURDAY  -> 6
                Calendar.SUNDAY    -> 7
                else               -> 1
            }
            val month = cal.get(Calendar.MONTH) + 1
            val day   = cal.get(Calendar.DAY_OF_MONTH)
            val weekNames = arrayOf("", "周一", "周二", "周三", "周四", "周五", "周六", "周日")
            views.setTextViewText(
                R.id.widget_date,
                "${month}月${day}日 · ${weekNames[flutterWeekday]}"
            )

            val json = prefs.getString("today_courses", null)
            val courses = mutableListOf<Pair<String, String>>()

            if (!json.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(json)
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val name     = obj.optString("name", "")
                        val time     = obj.optString("time", "")
                        val location = obj.optString("location", "")
                        val detail   = buildString {
                            if (time.isNotEmpty()) append(time)
                            if (location.isNotEmpty()) {
                                if (isNotEmpty()) append("  ")
                                append(location)
                            }
                        }
                        if (name.isNotEmpty()) courses.add(name to detail)
                    }
                } catch (_: Exception) {
                    // JSON 解析失败时显示空状态
                }
            }

            // 填充最多 3 条
            val slots = listOf(
                R.id.widget_course_1,
                R.id.widget_course_2,
                R.id.widget_course_3
            )
            val showCount = minOf(courses.size, 3)
            for (i in slots.indices) {
                if (i < showCount) {
                    val (name, detail) = courses[i]
                    val line = if (detail.isNotEmpty()) "● $name   $detail" else "● $name"
                    views.setTextViewText(slots[i], line)
                } else {
                    views.setTextViewText(slots[i], "")
                }
            }

            when {
                courses.isEmpty()      -> {
                    views.setTextViewText(R.id.widget_course_1, "今天没有课 🎉")
                    views.setTextViewText(R.id.widget_more, "")
                }
                courses.size > 3       ->
                    views.setTextViewText(R.id.widget_more, "还有 ${courses.size - 3} 节课，打开查看全部")
                else                   ->
                    views.setTextViewText(R.id.widget_more, "共 ${courses.size} 节课")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
