package ru.komet.app

object NfcExchange {

    const val AID = "F04B4F4D455431"

    private const val PREFIX = "KMT1:"
    private val STATUS_OK = byteArrayOf(0x90.toByte(), 0x00)
    private val STATUS_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())

    @Volatile var active: Boolean = false
    @Volatile var selfId: Long = 0L

    fun buildSelectResponse(): ByteArray {
        val id = selfId
        if (!active || id <= 0L) return STATUS_NOT_FOUND
        return (PREFIX + id).toByteArray(Charsets.UTF_8) + STATUS_OK
    }

    fun buildSelectCommand(): ByteArray {
        val aid = hexToBytes(AID)
        return byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, aid.size.toByte()) +
            aid + byteArrayOf(0x00)
    }

    fun parsePeerId(response: ByteArray?): Long? {
        if (response == null || response.size < 2) return null
        val sw1 = response[response.size - 2]
        val sw2 = response[response.size - 1]
        if (sw1 != 0x90.toByte() || sw2.toInt() != 0x00) return null
        val text = String(response.copyOfRange(0, response.size - 2), Charsets.UTF_8)
        if (!text.startsWith(PREFIX)) return null
        return text.substring(PREFIX.length).toLongOrNull()
    }

    private fun hexToBytes(hex: String): ByteArray {
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            out[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }
}
