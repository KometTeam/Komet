package ru.komet.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

class BleContactExchange(private val context: Context) {

    companion object {
        const val LOG_TAG = "BleExchange"
        val SERVICE_UUID: UUID = UUID.fromString("f04b4f4d-4554-3100-0000-000000000001")
        val CHAR_UUID: UUID = UUID.fromString("f04b4f4d-4554-3100-0000-000000000002")
        const val MFG_ID = 0x4B4D
    }

    var onReceived: ((Long, Long) -> Unit)? = null
    var onSent: ((Long) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    private val main = Handler(Looper.getMainLooper())

    private val manager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter? = manager?.adapter

    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var clientGatt: BluetoothGatt? = null

    @Volatile private var selfId: Long = 0L
    @Volatile private var selfSession: String = ""
    @Volatile private var selfPhone: Long = 0L
    @Volatile private var peerIdForWrite: Long = 0L
    @Volatile private var connecting = false
    @Volatile private var running = false

    fun start(selfId: Long, selfSession: String, selfPhone: Long) {
        val adapter = this.adapter
        if (adapter == null || !adapter.isEnabled) {
            emitError("bluetooth_off")
            return
        }
        this.selfId = selfId
        this.selfSession = selfSession
        this.selfPhone = selfPhone
        running = true
        startGattServer()
    }

    fun connectTo(peerSession: String, peerId: Long) {
        if (!running || connecting) return
        peerIdForWrite = peerId
        startScan(peerSession)
    }

    fun stop() {
        running = false
        connecting = false
        stopScan()
        stopAdvertising()
        try {
            clientGatt?.disconnect()
            clientGatt?.close()
        } catch (e: Exception) {
            Log.w(LOG_TAG, "client close: ${e.message}")
        }
        clientGatt = null
        try {
            gattServer?.close()
        } catch (e: Exception) {
            Log.w(LOG_TAG, "server close: ${e.message}")
        }
        gattServer = null
    }

    private fun startGattServer() {
        val server = try {
            manager?.openGattServer(context, serverCallback)
        } catch (e: SecurityException) {
            emitError("permission")
            return
        }
        if (server == null) {
            emitError("gatt_unavailable")
            return
        }
        gattServer = server
        val characteristic = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        val service = BluetoothGattService(
            SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )
        service.addCharacteristic(characteristic)
        try {
            server.addService(service)
        } catch (e: SecurityException) {
            emitError("permission")
        }
    }

    private fun startAdvertising() {
        val advertiser = adapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.w(LOG_TAG, "advertising unsupported on this device")
            return
        }
        this.advertiser = advertiser
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .addManufacturerData(MFG_ID, hexToBytes(selfSession))
            .build()
        val callback = object : AdvertiseCallback() {
            override fun onStartFailure(errorCode: Int) {
                Log.w(LOG_TAG, "advertise failed: $errorCode")
            }
        }
        advertiseCallback = callback
        try {
            advertiser.startAdvertising(settings, data, callback)
        } catch (e: SecurityException) {
            emitError("permission")
        }
    }

    private fun stopAdvertising() {
        val callback = advertiseCallback ?: return
        try {
            advertiser?.stopAdvertising(callback)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "stopAdvertising: ${e.message}")
        }
        advertiseCallback = null
    }

    private fun startScan(peerSession: String) {
        val scanner = adapter?.bluetoothLeScanner
        if (scanner == null) {
            emitError("scan_unavailable")
            return
        }
        this.scanner = scanner
        val target = peerSession.lowercase()
        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build(),
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                handleScanResult(result, target)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>?) {
                results?.forEach { handleScanResult(it, target) }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.w(LOG_TAG, "scan failed: $errorCode")
                emitError("scan_failed")
            }
        }
        scanCallback = callback
        try {
            scanner.startScan(filters, settings, callback)
        } catch (e: SecurityException) {
            emitError("permission")
        }
    }

    private fun stopScan() {
        val callback = scanCallback ?: return
        try {
            scanner?.stopScan(callback)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "stopScan: ${e.message}")
        }
        scanCallback = null
    }

    private fun handleScanResult(result: ScanResult?, target: String) {
        if (result == null || connecting) return
        val mfg = result.scanRecord?.getManufacturerSpecificData(MFG_ID) ?: return
        if (bytesToHex(mfg).lowercase() != target) return
        connecting = true
        stopScan()
        connectGatt(result.device)
    }

    private fun connectGatt(device: BluetoothDevice) {
        try {
            clientGatt = device.connectGatt(
                context,
                false,
                clientCallback,
                BluetoothDevice.TRANSPORT_LE,
            )
        } catch (e: SecurityException) {
            connecting = false
            emitError("permission")
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
            if (running) startAdvertising()
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            if (responseNeeded) {
                try {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        null,
                    )
                } catch (e: SecurityException) {
                    Log.w(LOG_TAG, "sendResponse: ${e.message}")
                }
            }
            if (characteristic?.uuid != CHAR_UUID || value == null) return
            val parts = String(value, Charsets.UTF_8).trim().split(":")
            val peerId = parts.getOrNull(0)?.toLongOrNull() ?: return
            val peerPhone = parts.getOrNull(1)?.toLongOrNull() ?: 0L
            if (peerId > 0L) emitReceived(peerId, peerPhone)
        }
    }

    private val clientCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    gatt?.discoverServices()
                } catch (e: SecurityException) {
                    Log.w(LOG_TAG, "discoverServices: ${e.message}")
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                try {
                    gatt?.close()
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "gatt close: ${e.message}")
                }
                if (gatt == clientGatt) clientGatt = null
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            if (gatt == null || status != BluetoothGatt.GATT_SUCCESS) {
                gatt?.disconnect()
                return
            }
            val characteristic = gatt.getService(SERVICE_UUID)?.getCharacteristic(CHAR_UUID)
            if (characteristic == null) {
                gatt.disconnect()
                return
            }
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            characteristic.value = "$selfId:$selfPhone".toByteArray(Charsets.UTF_8)
            try {
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(characteristic)
            } catch (e: SecurityException) {
                Log.w(LOG_TAG, "writeCharacteristic: ${e.message}")
                gatt.disconnect()
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            status: Int,
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val id = peerIdForWrite
                if (id > 0L) emitSent(id)
            }
            gatt?.disconnect()
        }
    }

    private fun emitReceived(id: Long, phone: Long) {
        main.post { onReceived?.invoke(id, phone) }
    }

    private fun emitSent(id: Long) {
        main.post { onSent?.invoke(id) }
    }

    private fun emitError(reason: String) {
        main.post { onError?.invoke(reason) }
    }

    private fun hexToBytes(hex: String): ByteArray {
        val clean = if (hex.length % 2 == 0) hex else "0$hex"
        val out = ByteArray(clean.length / 2)
        for (i in out.indices) {
            out[i] = clean.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) sb.append("%02x".format(b))
        return sb.toString()
    }
}
