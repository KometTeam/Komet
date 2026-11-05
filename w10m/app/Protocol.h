#pragma once
#include "../third_party/json.hpp"
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <vector>
#include "../third_party/zstd/zstd.h"
#include "../third_party/lz4/lz4frame.h"

namespace komet {
using Json = nlohmann::json;
using Bytes = std::vector<uint8_t>;
constexpr size_t max_body = 4 * 1024 * 1024;

inline Bytes ExpandLz4(Bytes const& source) {
    Bytes out;
    size_t pos = 0;
    auto length = [&](size_t n) {
        if (n == 15) {
            uint8_t b;
            do {
                if (pos == source.size()) throw std::runtime_error("Truncated LZ4 length");
                b = source[pos++];
                n += b;
                if (n > max_body) throw std::runtime_error("LZ4 size limit");
            } while (b == 255);
        }
        return n;
    };
    while (pos < source.size()) {
        auto token = source[pos++];
        auto literals = length(token >> 4);
        if (literals > source.size() - pos || literals > max_body - out.size())
            throw std::runtime_error("Invalid LZ4 literals");
        out.insert(out.end(), source.begin() + pos, source.begin() + pos + literals);
        pos += literals;
        if (pos == source.size()) break;
        if (source.size() - pos < 2) throw std::runtime_error("Truncated LZ4 offset");
        size_t offset = source[pos] | (size_t(source[pos + 1]) << 8);
        pos += 2;
        if (!offset || offset > out.size()) throw std::runtime_error("Invalid LZ4 offset");
        auto match = length(token & 15) + 4;
        if (match > max_body - out.size()) throw std::runtime_error("LZ4 size limit");
        for (size_t i = 0; i < match; ++i) out.push_back(out[out.size() - offset]);
    }
    return out;
}

inline Bytes ExpandCompressed(Bytes const& source) {
    if (source.size() >= 4 && source[0] == 0x28 && source[1] == 0xb5 && source[2] == 0x2f && source[3] == 0xfd) {
        auto context = ZSTD_createDStream();
        if (!context) throw std::runtime_error("Zstd allocation failed");
        Bytes result;
        try {
            if (ZSTD_isError(ZSTD_DCtx_setParameter(context, ZSTD_d_windowLogMax, 22))) throw std::runtime_error("Zstd window limit");
            ZSTD_inBuffer input{source.data(), source.size(), 0};
            Bytes buffer(65536);
            size_t pending = 1;
            while (input.pos < input.size || pending) {
                ZSTD_outBuffer output{buffer.data(), buffer.size(), 0};
                auto before = input.pos;
                pending = ZSTD_decompressStream(context, &output, &input);
                if (ZSTD_isError(pending) || output.pos > max_body - result.size()) throw std::runtime_error("Invalid or oversized Zstd frame");
                result.insert(result.end(), buffer.begin(), buffer.begin() + output.pos);
                if (!pending && input.pos == input.size) break;
                if (before == input.pos && !output.pos) throw std::runtime_error("Truncated Zstd frame");
            }
        } catch (...) { ZSTD_freeDStream(context); throw; }
        ZSTD_freeDStream(context);
        return result;
    }
    if (source.size() >= 4 && source[0] == 4 && source[1] == 0x22 && source[2] == 0x4d && source[3] == 0x18) {
        LZ4F_dctx* context = nullptr;
        if (LZ4F_isError(LZ4F_createDecompressionContext(&context, LZ4F_VERSION))) throw std::runtime_error("LZ4 frame allocation failed");
        Bytes result;
        size_t pos = 0;
        try {
            Bytes buffer(65536);
            for (;;) {
                size_t consumed = source.size() - pos;
                size_t written = buffer.size();
                auto pending = LZ4F_decompress(context, buffer.data(), &written, source.data() + pos, &consumed, nullptr);
                if (LZ4F_isError(pending) || written > max_body - result.size()) throw std::runtime_error("Invalid or oversized LZ4 frame");
                pos += consumed;
                result.insert(result.end(), buffer.begin(), buffer.begin() + written);
                if (!pending && pos == source.size()) break;
                if (!consumed && !written) throw std::runtime_error("Truncated LZ4 frame");
            }
        } catch (...) { LZ4F_freeDecompressionContext(context); throw; }
        LZ4F_freeDecompressionContext(context);
        return result;
    }
    return ExpandLz4(source);
}

class MsgReader {
    Bytes const& data_;
    size_t pos_ = 0;
    size_t nodes_ = 0;
    uint64_t Number(size_t count) {
        if (count > data_.size() - pos_) throw std::runtime_error("Truncated MessagePack");
        uint64_t result = 0;
        while (count--) result = (result << 8) | data_[pos_++];
        return result;
    }
    Json String(size_t count) {
        if (count > data_.size() - pos_) throw std::runtime_error("Truncated string");
        std::string value(data_.begin() + pos_, data_.begin() + pos_ + count);
        pos_ += count;
        return value;
    }
    Json Array(size_t count, int depth) {
        if (count > data_.size() - pos_) throw std::runtime_error("Invalid array size");
        auto out = Json::array();
        while (count--) out.push_back(Read(depth + 1));
        return out;
    }
    Json Map(size_t count, int depth) {
        if (count > (data_.size() - pos_) / 2) throw std::runtime_error("Invalid map size");
        auto out = Json::object();
        while (count--) {
            auto key = Read(depth + 1);
            if (!key.is_string() && !key.is_number_integer()) throw std::runtime_error("Invalid map key");
            auto name = key.is_string() ? key.get<std::string>() : key.dump();
            auto value = Read(depth + 1);
            out[name] = std::move(value);
        }
        return out;
    }
public:
    explicit MsgReader(Bytes const& data) : data_(data) {}
    Json Read(int depth = 0) {
        if (depth > 64 || ++nodes_ > 200000) throw std::runtime_error("MessagePack complexity limit");
        auto tag = Number(1);
        if (tag < 0x80) return tag;
        if (tag >= 0xe0) return int64_t(int8_t(tag));
        if ((tag & 0xe0) == 0xa0) return String(tag & 31);
        if ((tag & 0xf0) == 0x90) return Array(tag & 15, depth);
        if ((tag & 0xf0) == 0x80) return Map(tag & 15, depth);
        switch (tag) {
        case 0xc0: return nullptr;
        case 0xc2: return false;
        case 0xc3: return true;
        case 0xcc: return Number(1);
        case 0xcd: return Number(2);
        case 0xce: return Number(4);
        case 0xcf: return Number(8);
        case 0xd0: return int64_t(int8_t(Number(1)));
        case 0xd1: return int64_t(int16_t(Number(2)));
        case 0xd2: return int64_t(int32_t(Number(4)));
        case 0xd3: return int64_t(Number(8));
        case 0xca: {
            auto bits = uint32_t(Number(4));
            float value;
            std::memcpy(&value, &bits, 4);
            return value;
        }
        case 0xcb: {
            auto bits = Number(8);
            double value;
            std::memcpy(&value, &bits, 8);
            return value;
        }
        case 0xd9: return String(size_t(Number(1)));
        case 0xda: return String(size_t(Number(2)));
        case 0xdb: return String(size_t(Number(4)));
        case 0xdc: return Array(size_t(Number(2)), depth);
        case 0xdd: return Array(size_t(Number(4)), depth);
        case 0xde: return Map(size_t(Number(2)), depth);
        case 0xdf: return Map(size_t(Number(4)), depth);
        case 0xc4: case 0xc5: case 0xc6: {
            auto count = size_t(Number(size_t(1) << (tag - 0xc4)));
            if (count > data_.size() - pos_) throw std::runtime_error("Truncated binary");
            Bytes value(data_.begin() + pos_, data_.begin() + pos_ + count);
            pos_ += count;
            return Json::binary(std::move(value));
        }
        default: throw std::runtime_error("Unsupported MessagePack type");
        }
    }
    Json Decode() {
        auto value = Read();
        if (pos_ != data_.size()) throw std::runtime_error("Trailing MessagePack data");
        return value;
    }
};

struct Frame {
    uint8_t cmd;
    uint16_t seq;
    uint16_t opcode;
    Json payload;
};

inline Bytes Encode(uint8_t cmd, uint16_t seq, uint16_t opcode, Json const& payload = nullptr) {
    auto body = payload.is_null() ? Bytes{} : Json::to_msgpack(payload);
    if (body.size() > max_body) throw std::runtime_error("Frame size limit");
    Bytes out{10, cmd, uint8_t(seq >> 8), uint8_t(seq), uint8_t(opcode >> 8), uint8_t(opcode),
              0, uint8_t(body.size() >> 16), uint8_t(body.size() >> 8), uint8_t(body.size())};
    out.insert(out.end(), body.begin(), body.end());
    return out;
}

inline Bytes TakeFrame(Bytes& input) {
    if (input.size() < 10) return {};
    size_t count = (size_t(input[7]) << 16) | (size_t(input[8]) << 8) | input[9];
    if (input[0] != 10 || count > max_body) throw std::runtime_error("Invalid stream frame");
    if (input.size() < count + 10) return {};
    Bytes frame(input.begin(), input.begin() + count + 10);
    input.erase(input.begin(), input.begin() + count + 10);
    return frame;
}

inline Frame Decode(Bytes const& data) {
    if (data.size() < 10 || data[0] != 10 || data[1] > 3) throw std::runtime_error("Invalid frame header");
    size_t count = (size_t(data[7]) << 16) | (size_t(data[8]) << 8) | data[9];
    if (count > max_body || data.size() != count + 10) throw std::runtime_error("Invalid frame length");
    Bytes body(data.begin() + 10, data.end());
    if (data[6]) body = ExpandCompressed(body);
    return {data[1], uint16_t((data[2] << 8) | data[3]), uint16_t((data[4] << 8) | data[5]),
            body.empty() ? Json(nullptr) : MsgReader(body).Decode()};
}

inline std::string Text(Json const& object, char const* key, std::string fallback = {}) {
    auto it = object.find(key);
    return it != object.end() && it->is_string() ? it->get<std::string>() : fallback;
}

inline std::string FirstText(Json const& object, std::initializer_list<char const*> keys) {
    for (auto key : keys) { auto text = Text(object, key); if (!text.empty()) return text; }
    return {};
}

inline int64_t Integer(Json const& object, char const* key, int64_t fallback = 0) {
    auto it = object.find(key);
    if (it == object.end()) return fallback;
    if (it->is_number_integer()) return it->get<int64_t>();
    if (it->is_string()) {
        try { return std::stoll(it->get<std::string>()); } catch (...) {}
    }
    return fallback;
}

inline Json Object(Json const& object, char const* key) {
    auto it = object.find(key);
    return it != object.end() && it->is_object() ? *it : Json::object();
}

inline Json Array(Json const& object, char const* key) {
    auto it = object.find(key);
    return it != object.end() && it->is_array() ? *it : Json::array();
}
}
