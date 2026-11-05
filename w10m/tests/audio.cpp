#include "../app/Audio.h"
#include "../third_party/ogg/include/ogg/ogg.h"
#include <cmath>
#include <iostream>

using komet::Bytes;

Bytes Fixture(int channels) {
    int error = 0;
    auto encoder = opus_encoder_create(48000, channels, OPUS_APPLICATION_AUDIO, &error);
    if (!encoder) throw std::runtime_error("encoder");
    ogg_stream_state ogg{};
    ogg_stream_init(&ogg, 12345);
    Bytes file;
    int64_t packet_number = 0;
    auto packet = [&](Bytes& bytes, int64_t granule, bool bos, bool eos) {
        ogg_packet input{};
        input.packet = bytes.data(); input.bytes = long(bytes.size()); input.b_o_s = bos; input.e_o_s = eos;
        input.granulepos = granule; input.packetno = packet_number++;
        ogg_stream_packetin(&ogg, &input);
        ogg_page page{};
        while (ogg_stream_flush(&ogg, &page)) {
            file.insert(file.end(), page.header, page.header + page.header_len);
            file.insert(file.end(), page.body, page.body + page.body_len);
        }
    };
    int skip = 0;
    opus_encoder_ctl(encoder, OPUS_GET_LOOKAHEAD(&skip));
    Bytes head{'O','p','u','s','H','e','a','d',1,uint8_t(channels),uint8_t(skip),uint8_t(skip >> 8),0x80,0xbb,0,0,0,0,0};
    packet(head, 0, true, false);
    Bytes tags{'O','p','u','s','T','a','g','s',0,0,0,0,0,0,0,0};
    packet(tags, 0, false, false);
    for (int frame = 0; frame < 11; ++frame) {
        std::vector<opus_int16> pcm(960 * channels);
        for (int i = 0; i < 960; ++i) for (int c = 0; c < channels; ++c) pcm[i * channels + c] = opus_int16(8000 * std::sin((frame * 960 + i) * 0.0576));
        Bytes data(4000);
        int count = opus_encode(encoder, pcm.data(), 960, data.data(), int(data.size()));
        if (count < 0) throw std::runtime_error("encode");
        data.resize(count);
        packet(data, frame == 10 ? 9600 + skip : (frame + 1) * 960, false, frame == 10);
    }
    opus_encoder_destroy(encoder);
    ogg_stream_clear(&ogg);
    return file;
}

int main() {
    try {
        for (int channels : {1, 2}) {
            auto input = Fixture(channels);
            Bytes wave;
            komet::DecodeOpusWave(input, [&](Bytes const& part) { wave.insert(wave.end(), part.begin(), part.end()); });
            if (wave.size() != 44 + 9600 * 4 || std::memcmp(wave.data(), "RIFF", 4) || std::memcmp(wave.data() + 8, "WAVE", 4)) throw std::runtime_error("WAV size or header");
            int peak = 0;
            for (size_t i = 44; i < wave.size(); i += 2) peak = std::max(peak, std::abs(int(int16_t(uint16_t(wave[i]) | uint16_t(wave[i + 1]) << 8))));
            if (peak < 1000) throw std::runtime_error("decoded silence");
        }
        for (auto bad : {Bytes{}, Bytes{'O','g','g','S'}, Bytes(1024, 255)}) {
            bool rejected = false;
            try { komet::DecodeOpusWave(bad, [](auto const&) {}); } catch (...) { rejected = true; }
            if (!rejected) throw std::runtime_error("corrupt stream accepted");
        }
        std::cout << "PASS: synthetic mono/stereo Ogg Opus decoded to 48 kHz WAV, exact duration, non-silent PCM, corrupt inputs rejected\n";
        return 0;
    } catch (std::exception const& e) { std::cerr << e.what() << '\n'; return 1; }
}
