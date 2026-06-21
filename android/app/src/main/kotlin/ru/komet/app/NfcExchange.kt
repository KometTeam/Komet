package ru.komet.app

object NfcExchange {

    const val AID = "F04B4F4D455431"

    private const val PREFIX = "KMT2:"
    private val STATUS_OK = byteArrayOf(0x90.toByte(), 0x00)
    private val STATUS_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())

    @Volatile var active: Boolean = false
    @Volatile var selfId: Long = 0L
    @Volatile var selfSession: String = ""
    @Volatile var selfPhone: Long = 0L

    @Volatile var onServed: (() -> Unit)? = null

    data class Peer(val id: Long, val session: String, val phone: Long)

    fun buildSelectResponse(): ByteArray {
        val id = selfId
        val session = selfSession
        if (!active || id <= 0L || session.isEmpty()) return STATUS_NOT_FOUND
        onServed?.invoke()
        return (PREFIX + id + ":" + session + ":" + selfPhone)
            .toByteArray(Charsets.UTF_8) + STATUS_OK
    }

    fun buildSelectCommand(): ByteArray {
        val aid = hexToBytes(AID)
        return byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, aid.size.toByte()) +
            aid + byteArrayOf(0x00)
    }

    fun parsePeer(response: ByteArray?): Peer? {
        if (response == null || response.size < 2) return null
        val sw1 = response[response.size - 2]
        val sw2 = response[response.size - 1]
        if (sw1 != 0x90.toByte() || sw2.toInt() != 0x00) return null
        val text = String(response.copyOfRange(0, response.size - 2), Charsets.UTF_8)
        if (!text.startsWith(PREFIX)) return null
        val parts = text.substring(PREFIX.length).split(":")
        if (parts.size < 2) return null
        val id = parts[0].toLongOrNull() ?: return null
        val session = parts[1]
        if (session.isEmpty()) return null
        val phone = parts.getOrNull(2)?.toLongOrNull() ?: 0L
        return Peer(id, session, phone)
    }

    private fun hexToBytes(hex: String): ByteArray {
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            out[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }
}
