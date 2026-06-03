package ru.komet.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val channelName = "ru.komet.app/vpn_bypass"
    private val iconAliases = listOf("DefaultIcon", "MinimalIcon")

    private companion object {
        const val LOG_TAG = "VpnBypass"
    }

    private fun applyIcon(name: String) {
        val pm = packageManager
        for (alias in iconAliases) {
            val component = ComponentName(packageName, "$packageName.$alias")
            val state = if (alias == name) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                component,
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
        Handler(Looper.getMainLooper()).postDelayed({
            finishAndRemoveTask()
        }, 250L)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectInterfaces" -> result.success(detectInterfaces())
                "bindToNonVpnNetwork" -> bindToNonVpnNetwork(result)
                "unbindNetwork" -> result.success(unbindNetwork())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.komet.app/app_icon",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAppIcon" -> {
                    val name = call.argument<String>("name")
                    if (name == null || !iconAliases.contains(name)) {
                        result.error("INVALID_ICON", "Unknown icon: $name", null)
                        return@setMethodCallHandler
                    }
                    try {
                        applyIcon(name)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("APPLY_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.komet.app/upload_service",
        ).setMethodCallHandler { call, result ->
            val ctx = this
            when (call.method) {
                "start" -> {
                    val filename = call.argument<String>("filename") ?: "Файл"
                    val intent = Intent(ctx, UploadForegroundService::class.java).apply {
                        action = UploadForegroundService.ACTION_START
                        putExtra(UploadForegroundService.EXTRA_FILENAME, filename)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "update" -> {
                    val filename = call.argument<String>("filename") ?: "Файл"
                    val progress = call.argument<Int>("progress") ?: 0
                    val speed    = call.argument<Long>("speed") ?: 0L
                    val intent = Intent(ctx, UploadForegroundService::class.java).apply {
                        action = UploadForegroundService.ACTION_UPDATE
                        putExtra(UploadForegroundService.EXTRA_FILENAME, filename)
                        putExtra(UploadForegroundService.EXTRA_PROGRESS, progress)
                        putExtra(UploadForegroundService.EXTRA_SPEED, speed)
                    }
                    startService(intent)
                    result.success(null)
                }
                "stop" -> {
                    startService(Intent(ctx, UploadForegroundService::class.java).apply {
                        action = UploadForegroundService.ACTION_STOP
                    })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun connectivityManager(): ConnectivityManager =
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    // Перечисляет активные интерфейсы: есть ли tun-туннель и какие прямые.
    private fun detectInterfaces(): Map<String, Any> {
        val tunNames = ArrayList<String>()
        val directNames = ArrayList<String>()
        val interfaces = try {
            Collections.list(NetworkInterface.getNetworkInterfaces())
        } catch (_: Exception) {
            emptyList<NetworkInterface>()
        }
        for (nif in interfaces) {
            val name = nif.name ?: continue
            val up = try {
                nif.isUp && !nif.isLoopback
            } catch (_: Exception) {
                false
            }
            if (!up) continue
            when {
                name.startsWith("tun") || name.startsWith("ppp") ||
                    name.startsWith("ipsec") || name.startsWith("wg") ->
                    tunNames.add(name)
                name.startsWith("wlan") || name.startsWith("rmnet") ||
                    name.startsWith("eth") ->
                    directNames.add(name)
            }
        }
        return mapOf(
            "hasTun" to tunNames.isNotEmpty(),
            "hasVpn" to hasVpnTransport(),
            "tunNames" to tunNames,
            "directInterfaces" to directNames,
        )
    }

    // VPN активен, даже если tun-интерфейс не виден приложению (Android 10+).
    private fun hasVpnTransport(): Boolean {
        val cm = connectivityManager()
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) {
                return true
            }
        }
        return false
    }

    private data class Candidate(
        val network: Network,
        val iface: String?,
        val transport: String,
        val score: Int,
    )

    // Привязка к не-VPN сети. Надёжный путь — попросить систему выдать
    // подходящую сеть через NetworkCallback (валидный, привязываемый
    // Network), и лишь при тайм-ауте — перебор getAllNetworks().
    private fun bindToNonVpnNetwork(result: MethodChannel.Result) {
        val cm = connectivityManager()
        val main = Handler(Looper.getMainLooper())
        val done = AtomicBoolean(false)
        var callback: ConnectivityManager.NetworkCallback? = null

        fun finish(map: Map<String, Any?>) {
            if (!done.compareAndSet(false, true)) return
            callback?.let {
                try {
                    cm.unregisterNetworkCallback(it)
                } catch (_: Exception) {
                }
            }
            main.post { result.success(map) }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addTransportType(NetworkCapabilities.TRANSPORT_ETHERNET)
            .build()

        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                val caps = cm.getNetworkCapabilities(network)
                val iface = cm.getLinkProperties(network)?.interfaceName
                val transport = when {
                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                        == true -> "wifi"
                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
                        == true -> "ethernet"
                    else -> "cellular"
                }
                val ok = cm.bindProcessToNetwork(network)
                Log.i(LOG_TAG, "onAvailable iface=$iface t=$transport bound=$ok")
                finish(
                    mapOf(
                        "bound" to ok,
                        "interface" to iface,
                        "transport" to transport,
                        "reason" to if (ok) {
                            null
                        } else {
                            "bind_rejected_maybe_lockdown"
                        },
                    ),
                )
            }
        }

        callback = cb
        try {
            cm.registerNetworkCallback(request, cb)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "registerNetworkCallback failed: ${e.message}")
            finish(bindByEnumeration())
            return
        }

        main.postDelayed({
            if (done.get()) return@postDelayed
            Log.w(LOG_TAG, "callback timeout — fallback to enumeration")
            finish(bindByEnumeration())
        }, 4000L)
    }

    // Запасной путь: перебор getAllNetworks(). Жёсткий фильтр — только
    // исключение VPN-транспорта; INTERNET/NOT_VPN/VALIDATED лишь повышают
    // приоритет (физическая сеть под VPN часто теряет эти capability).
    private fun bindByEnumeration(): Map<String, Any?> {
        val cm = connectivityManager()
        val networks = cm.allNetworks
        val candidates = ArrayList<Candidate>()

        for (network in networks) {
            val caps = cm.getNetworkCapabilities(network)
            val iface = cm.getLinkProperties(network)?.interfaceName
            Log.i(LOG_TAG, "net=$network iface=$iface caps=$caps")
            if (caps == null) continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue

            val baseScore = when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 3
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 2
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 1
                else -> continue
            }
            val transport = when (baseScore) {
                3 -> "wifi"
                2 -> "ethernet"
                else -> "cellular"
            }
            val internet =
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            val notVpn =
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            val validated =
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            val score = baseScore * 8 +
                (if (internet) 4 else 0) +
                (if (notVpn) 2 else 0) +
                (if (validated) 1 else 0)
            candidates.add(Candidate(network, iface, transport, score))
        }

        candidates.sortByDescending { it.score }
        Log.i(LOG_TAG, "candidates=${candidates.map { "${it.iface}:${it.score}" }}")

        if (candidates.isEmpty()) {
            return mapOf(
                "bound" to false,
                "reason" to "no_non_vpn_network(scanned=${networks.size})",
            )
        }

        for (c in candidates) {
            if (cm.bindProcessToNetwork(c.network)) {
                Log.i(LOG_TAG, "bound to ${c.iface} (${c.transport})")
                return mapOf(
                    "bound" to true,
                    "interface" to c.iface,
                    "transport" to c.transport,
                    "reason" to null,
                )
            }
            Log.w(LOG_TAG, "bindProcessToNetwork failed for ${c.iface}")
        }
        return mapOf("bound" to false, "reason" to "bind_blocked_maybe_lockdown")
    }

    private fun unbindNetwork(): Map<String, Any?> {
        connectivityManager().bindProcessToNetwork(null)
        return mapOf("bound" to false, "reason" to "unbound")
    }
}
