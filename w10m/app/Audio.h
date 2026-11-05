#pragma once
#include "Protocol.h"
#include "../third_party/opusfile/include/opusfile.h"
#include <functional>
#include <memory>

namespace komet {
inline void DecodeOpusWave(Bytes const& input, std::function<void(Bytes const&)> const& write) {
    int error = 0;
    std::unique_ptr<OggOpusFile, decltype(&op_free)> decoder(op_open_memory(input.data(), input.size(), &error), op_free);
    if (!decoder) throw std::runtime_error("Не удалось прочитать Ogg/Opus: " + std::to_string(error));
    auto frames = op_pcm_total(decoder.get(), -1);
    if (frames <= 0 || frames > 48000LL * 1800) throw std::runtime_error("Недопустимая длительность аудио.");
    uint32_t length = uint32_t(frames * 4);
    Bytes header;
    auto word = [&](uint32_t value, int bytes) { while (bytes--) { header.push_back(uint8_t(value)); value >>= 8; } };
    auto text = [&](char const* value) { for (int i = 0; i < 4; ++i) header.push_back(uint8_t(value[i])); };
    text("RIFF"); word(length + 36, 4); text("WAVE"); text("fmt "); word(16, 4);
    word(1, 2); word(2, 2); word(48000, 4); word(192000, 4); word(4, 2); word(16, 2);
    text("data"); word(length, 4);
    write(header);
    std::vector<opus_int16> samples(11520);
    int64_t decoded = 0;
    for (;;) {
        int count = op_read_stereo(decoder.get(), samples.data(), int(samples.size()));
        if (!count) break;
        if (count < 0) throw std::runtime_error("Повреждённое голосовое сообщение: " + std::to_string(count));
        decoded += count;
        if (decoded > frames) throw std::runtime_error("Некорректная длина аудио.");
        Bytes pcm(size_t(count) * 4);
        for (size_t i = 0; i < size_t(count) * 2; ++i) {
            pcm[i * 2] = uint8_t(samples[i]);
            pcm[i * 2 + 1] = uint8_t(uint16_t(samples[i]) >> 8);
        }
        write(pcm);
    }
    if (decoded != frames) throw std::runtime_error("Аудиофайл загружен не полностью.");
}
}
