package ru.komet.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : FlutterActivity() {

    private val channelName = "ru.komet.app/vpn_bypass"

    private companion object {
        const val LOG_TAG = "VpnBypass"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectInterfaces" -> result.success(detectInterfaces())
                "bindToNonVpnNetwork" -> result.success(bindToNonVpnNetwork())
                "unbindNetwork" -> result.success(unbindNetwork())
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

    // Привязывает процесс к не-VPN сети: Wi-Fi → Ethernet → моб.
    // Жёсткий фильтр — только исключение VPN-транспорта; INTERNET/NOT_VPN/
    // VALIDATED лишь повышают приоритет (физическая сеть под активным VPN
    // часто теряет эти capability, но через неё всё равно можно ходить).
    private fun bindToNonVpnNetwork(): Map<String, Any?> {
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
        return mapOf("bound" to false, "reason" to "bind_failed")
    }

    private fun unbindNetwork(): Map<String, Any?> {
        connectivityManager().bindProcessToNetwork(null)
        return mapOf("bound" to false, "reason" to "unbound")
    }
}
