package ru.komet.app

import android.app.Application
import com.ryanheise.audioservice.AudioServicePlugin

// id движка audio_service обязан быть выставлен до создания первого FlutterEngine.
// Создаёт его не только активити: AudioService поднимает движок сам, когда система
// стартует сервис по кнопке на гарнитуре. Выставленный позже id даёт второй движок —
// второй изолят со своим соединением и своей сессией БД.
class KometApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        AudioServicePlugin.setFlutterEngineId(ENGINE_ID)
    }

    companion object {
        const val ENGINE_ID = "komet_keep_engine"
    }
}
