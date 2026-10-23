package com.example.oushudh_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Draws the home-screen widget. The Flutter app saves the text into
// "widgetData" (keys w_header, w_count, w_text0.., w_dose0.. ), and this
// class only reads those values and puts them on the screen.
class OushudhWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val rows = listOf(
            Triple(R.id.w_row0, R.id.w_text0, R.id.w_tick0),
            Triple(R.id.w_row1, R.id.w_text1, R.id.w_tick1),
            Triple(R.id.w_row2, R.id.w_text2, R.id.w_tick2)
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.oushudh_widget)

            // Tapping the widget background opens the app
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, openApp)

            views.setTextViewText(
                R.id.w_header,
                widgetData.getString("w_header", "💊 ওষুধের সাথী") ?: ""
            )

            val count = (widgetData.getString("w_count", "0") ?: "0").toIntOrNull() ?: 0

            for (i in 0..2) {
                val (rowId, textId, tickId) = rows[i]
                if (i < count) {
                    views.setViewVisibility(rowId, View.VISIBLE)
                    views.setTextViewText(textId, widgetData.getString("w_text$i", "") ?: "")
                    val dose = widgetData.getString("w_dose$i", "") ?: ""
                    // Tapping the tick runs the Dart function backgroundCallback
                    val tick = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("oushudh://tick?dose=$dose")
                    )
                    views.setOnClickPendingIntent(tickId, tick)
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }

            if (count == 0) {
                views.setViewVisibility(R.id.w_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.w_empty,
                    widgetData.getString("w_empty", "অ্যাপ খুলে ওষুধ যোগ করুন") ?: ""
                )
            } else {
                views.setViewVisibility(R.id.w_empty, View.GONE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
