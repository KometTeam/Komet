package ru.komet.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : FlutterActivity() {

    private val channelName = "ru.komet.app/vpn_bypass"

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

    // Привязывает процесс к не-VPN сети: Wi-Fi → Ethernet → моб.
    private fun bindToNonVpnNetwork(): Map<String, Any?> {
        val cm = connectivityManager()
        var best: Network? = null
        var bestIface: String? = null
        var bestTransport: String? = null
        var bestScore = -1

        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)) continue

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
            val validated =
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            val score = baseScore * 2 + if (validated) 1 else 0
            if (score > bestScore) {
                bestScore = score
                best = network
                bestIface = cm.getLinkProperties(network)?.interfaceName
                bestTransport = transport
            }
        }

        val chosen = best
            ?: return mapOf("bound" to false, "reason" to "no_non_vpn_network")

        val ok = cm.bindProcessToNetwork(chosen)
        return mapOf(
            "bound" to ok,
            "interface" to bestIface,
            "transport" to bestTransport,
            "reason" to if (ok) null else "bind_failed",
        )
    }

    private fun unbindNetwork(): Map<String, Any?> {
        connectivityManager().bindProcessToNetwork(null)
        return mapOf("bound" to false, "reason" to "unbound")
    }
}
