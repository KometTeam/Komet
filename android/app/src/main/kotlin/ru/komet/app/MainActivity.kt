package ru.komet.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections
import java.util.Random
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val channelName = "ru.komet.app/vpn_bypass"
    private val iconComponents = listOf("MainActivity", "MinimalIcon")

    private var nfcAdapter: NfcAdapter? = null
    private var nfcEvents: EventChannel.EventSink? = null
    private val nfcHandler = Handler(Looper.getMainLooper())
    private val nfcJitter = Random()
    private val seenPeers = HashSet<Long>()
    @Volatile private var nfcCycling = false
    private val nfcReaderCallback = NfcAdapter.ReaderCallback { tag -> onNfcTagDiscovered(tag) }

    private var ble: BleContactExchange? = null
    private var pendingSelfId = 0L
    private var pendingSelfPhone = 0L
    private var pendingSession = ""
    private var pendingPeer: NfcExchange.Peer? = null
    @Volatile private var exchangingEmitted = false

    private companion object {
        const val LOG_TAG = "VpnBypass"
        const val NFC_TAG = "NfcExchange"
        const val NFC_PHASE_MIN_MS = 350L
        const val NFC_PHASE_JITTER_MS = 400
        const val BLE_PERMS_REQUEST = 7711
        val NFC_READER_FLAGS = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
    }

    private fun applyIcon(name: String) {
        val pm = packageManager
        for (alias in iconComponents) {
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

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.komet.app/nfc",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(nfcStatus())
                "start" -> {
                    val selfId = longArg(call.argument<Any>("selfId"))
                    val selfPhone = longArg(call.argument<Any>("selfPhone"))
                    if (selfId <= 0L) {
                        result.error("INVALID_ID", "selfId must be positive", null)
                    } else {
                        startNfcExchange(selfId, selfPhone)
                        result.success(null)
                    }
                }
                "stop" -> {
                    stopNfcExchange()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.komet.app/nfc_events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                nfcEvents = events
            }

            override fun onCancel(arguments: Any?) {
                nfcEvents = null
            }
        })

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
                    if (name == null || !iconComponents.contains(name)) {
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

    private fun nfcStatus(): Map<String, Any> {
        val adapter = nfcAdapter
        return mapOf(
            "supported" to (adapter != null),
            "enabled" to (adapter?.isEnabled == true),
        )
    }

    private fun startNfcExchange(selfId: Long, selfPhone: Long) {
        val session = "%08x".format(nfcJitter.nextInt())
        NfcExchange.selfId = selfId
        NfcExchange.selfSession = session
        NfcExchange.selfPhone = selfPhone
        NfcExchange.active = true
        NfcExchange.onServed = { onNfcServed() }
        seenPeers.clear()
        exchangingEmitted = false
        pendingPeer = null
        pendingSelfId = selfId
        pendingSelfPhone = selfPhone
        pendingSession = session
        nfcCycling = true
        nfcHandler.removeCallbacksAndMessages(null)
        nfcReaderOn()
        ensureBleStarted()
    }

    private fun stopNfcExchange() {
        nfcCycling = false
        NfcExchange.active = false
        NfcExchange.selfId = 0L
        NfcExchange.selfSession = ""
        NfcExchange.selfPhone = 0L
        NfcExchange.onServed = null
        pendingPeer = null
        nfcHandler.removeCallbacksAndMessages(null)
        nfcReaderDisable()
        ble?.stop()
    }

    private fun blePermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasBlePermissions(): Boolean = blePermissions().all {
        ContextCompat.checkSelfPermission(this, it) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun ensureBleStarted() {
        if (hasBlePermissions()) {
            startBle()
        } else {
            ActivityCompat.requestPermissions(this, blePermissions(), BLE_PERMS_REQUEST)
        }
    }

    private fun startBle() {
        val exchange = ble ?: BleContactExchange(applicationContext).also {
            it.onReceived = { id, phone -> revealPeer(id, phone) }
            it.onSent = { _ -> pendingPeer?.let { p -> revealPeer(p.id, p.phone) } }
            it.onError = { reason -> onBleError(reason) }
            ble = it
        }
        exchange.start(pendingSelfId, pendingSession, pendingSelfPhone)
    }

    private fun emitExchanging() {
        if (exchangingEmitted) return
        exchangingEmitted = true
        nfcEvents?.success(mapOf("event" to "exchanging"))
    }

    private fun revealPeer(id: Long, phone: Long) {
        if (id == NfcExchange.selfId || !seenPeers.add(id)) return
        nfcEvents?.success(mapOf("event" to "received", "id" to id, "phone" to phone))
    }

    private fun longArg(value: Any?): Long = when (value) {
        is Int -> value.toLong()
        is Long -> value
        else -> 0L
    }

    private fun onBleError(reason: String) {
        nfcEvents?.success(mapOf("event" to "error", "reason" to reason))
    }

    private fun onNfcServed() {
        nfcHandler.post {
            if (!NfcExchange.active) return@post
            nfcCycling = false
            nfcReaderDisable()
            emitExchanging()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BLE_PERMS_REQUEST) return
        if (!NfcExchange.active) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (granted) {
            startBle()
        } else {
            onBleError("permission")
        }
    }

    private fun nfcReaderOn() {
        if (!nfcCycling) return
        nfcReaderEnable()
        nfcHandler.postDelayed({ nfcReaderOff() }, nfcPhaseDuration())
    }

    private fun nfcReaderOff() {
        if (!nfcCycling) return
        nfcReaderDisable()
        nfcHandler.postDelayed({ nfcReaderOn() }, nfcPhaseDuration())
    }

    private fun nfcPhaseDuration(): Long =
        NFC_PHASE_MIN_MS + nfcJitter.nextInt(NFC_PHASE_JITTER_MS)

    private fun nfcReaderEnable() {
        val adapter = nfcAdapter ?: return
        try {
            adapter.enableReaderMode(this, nfcReaderCallback, NFC_READER_FLAGS, null)
        } catch (e: Exception) {
            Log.w(NFC_TAG, "enableReaderMode failed: ${e.message}")
        }
    }

    private fun nfcReaderDisable() {
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (e: Exception) {
            Log.w(NFC_TAG, "disableReaderMode failed: ${e.message}")
        }
    }

    private fun onNfcTagDiscovered(tag: Tag) {
        val isoDep = IsoDep.get(tag) ?: return
        val peer = try {
            isoDep.connect()
            NfcExchange.parsePeer(isoDep.transceive(NfcExchange.buildSelectCommand()))
        } catch (e: Exception) {
            Log.w(NFC_TAG, "transceive failed: ${e.message}")
            null
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {
            }
        }
        if (peer == null || peer.id <= 0L) return
        nfcHandler.post {
            if (peer.id == NfcExchange.selfId) return@post
            nfcCycling = false
            nfcReaderDisable()
            emitExchanging()
            pendingPeer = peer
            ble?.connectTo(peer.session, peer.id)
            nfcHandler.postDelayed({ revealPeer(peer.id, peer.phone) }, 3000L)
        }
    }

    override fun onPause() {
        super.onPause()
        if (NfcExchange.active) {
            stopNfcExchange()
            nfcEvents?.success(mapOf("event" to "cancelled"))
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
