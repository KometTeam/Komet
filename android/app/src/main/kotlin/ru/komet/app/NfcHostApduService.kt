package ru.komet.app

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class NfcHostApduService : HostApduService() {

    private val selectHeader = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00)
    private val statusNotFound = byteArrayOf(0x6A, 0x82.toByte())

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null || !isSelectApdu(commandApdu)) return statusNotFound
        return NfcExchange.buildSelectResponse()
    }

    override fun onDeactivated(reason: Int) {}

    private fun isSelectApdu(apdu: ByteArray): Boolean {
        if (apdu.size < selectHeader.size) return false
        for (i in selectHeader.indices) {
            if (apdu[i] != selectHeader[i]) return false
        }
        return true
    }
}
