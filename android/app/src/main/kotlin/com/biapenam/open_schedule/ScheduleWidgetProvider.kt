package com.example.schedule_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_DATE_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = android.content.ComponentName(context, ScheduleWidgetProvider::class.java)
            manager.getAppWidgetIds(provider).forEach { id ->
                updateAppWidget(context, manager, id)
            }
        }
    }

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

            val json = try {
                buildTodayCoursesJson(prefs, cal, flutterWeekday)
            } catch (_: Exception) {
                "[]"
            }
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

        private fun buildTodayCoursesJson(
            prefs: SharedPreferences,
            today: Calendar,
            weekday: Int
        ): String {
            val schedules = JSONArray(prefs.getString("schedules", "[]"))
            val activeId = prefs.getString("active_schedule_id", null)
                ?: return "[]"
            var schedule: JSONObject? = null
            for (i in 0 until schedules.length()) {
                val candidate = schedules.optJSONObject(i)
                if (candidate?.optString("id") == activeId) {
                    schedule = candidate
                    break
                }
            }
            schedule ?: return "[]"

            val start = schedule.optString("semesterStart")
            val totalWeeks = schedule.optInt("totalWeeks", 20)
            val week = semesterWeek(start, today)
            if (week !in 1..totalWeeks) return "[]"

            val times = schedule.optJSONArray("sectionStartTimes") ?: JSONArray()
            val duration = schedule.optInt("sectionDuration", 45)
            val rawCourses = JSONArray(prefs.getString("courses_$activeId", "[]"))
            val result = JSONArray()
            for (i in 0 until rawCourses.length()) {
                val course = rawCourses.optJSONObject(i) ?: continue
                if (course.optInt("dayOfWeek") != weekday) continue
                val weeks = course.optJSONArray("weeks") ?: continue
                var hasWeek = false
                for (j in 0 until weeks.length()) {
                    if (weeks.optInt(j) == week) {
                        hasWeek = true
                        break
                    }
                }
                if (!hasWeek) continue

                val startSection = course.optInt("startSection", 1).coerceAtLeast(1)
                val endSection = course.optInt("endSection", startSection).coerceAtLeast(startSection)
                val startTime = times.optString(startSection - 1, "08:00")
                val endTime = addMinutes(times.optString(endSection - 1, startTime), duration)
                result.put(JSONObject().apply {
                    put("name", course.optString("name", ""))
                    put("time", "$startTime-$endTime")
                    put("location", course.optString("location", ""))
                })
            }
            return result.toString()
        }

        private fun semesterWeek(rawStart: String, today: Calendar): Int {
            if (rawStart.length < 10) return 1
            val start = Calendar.getInstance().apply {
                clear()
                set(rawStart.substring(0, 4).toIntOrNull() ?: return 1,
                    (rawStart.substring(5, 7).toIntOrNull() ?: return 1) - 1,
                    rawStart.substring(8, 10).toIntOrNull() ?: return 1)
            }
            val todayDate = Calendar.getInstance().apply {
                clear()
                set(today.get(Calendar.YEAR), today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH))
            }
            val days = ((todayDate.timeInMillis - start.timeInMillis) / 86_400_000L).toInt()
            if (days < 0) return 0
            return days / 7 + 1
        }

        private fun addMinutes(raw: String, duration: Int): String {
            val parts = raw.split(":")
            val minutes = (parts.getOrNull(0)?.toIntOrNull() ?: 8) * 60 +
                (parts.getOrNull(1)?.toIntOrNull() ?: 0) + duration
            return String.format(Locale.US, "%02d:%02d", minutes / 60, minutes % 60)
        }
    }
}
