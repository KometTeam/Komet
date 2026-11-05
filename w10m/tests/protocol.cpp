#include "../app/Protocol.h"
#include <iostream>
#include <random>
#include <limits>

using namespace komet;
int checks = 0;
void Check(bool condition, char const* name) {
    ++checks;
    if (!condition) throw std::runtime_error(name);
}
template<typename F> void Reject(F function) {
    bool threw = false;
    try { function(); } catch (std::exception const&) { threw = true; }
    Check(threw, "Malformed input accepted");
}

int main() {
    try {
        auto golden = Encode(0, 0x1234, 64, {{"text", "test"}});
        Check(golden == Bytes({10, 0, 0x12, 0x34, 0, 64, 0, 0, 0, 11, 0x81, 0xa4, 't', 'e', 'x', 't', 0xa4, 't', 'e', 's', 't'}), "Wire format mismatch");
        Json payload = {{"id", INT64_C(9007199254740993)}, {"negative", std::numeric_limits<int64_t>::min()},
            {"unsigned", std::numeric_limits<uint64_t>::max()}, {"text", "Привет 👋"},
            {"items", Json::array({nullptr, true, false, -32, -33, 128, 65536, 1.25})},
            {"binary", Json::binary(Bytes{0, 255, 1})}};
        auto frame = Decode(Encode(0, 32767, 49, payload));
        Check(frame.seq == 32767 && frame.opcode == 49 && frame.payload == payload, "Round trip mismatch");
        Check(Decode(Encode(1, 5, 1)).payload.is_null(), "Empty ping mismatch");
        Check(Object(Json(nullptr), "contact").is_object(), "Null object was not normalized");
        Check(Array(Json{{"messages", nullptr}}, "messages").empty(), "Null optional array was not normalized");
        Check(MsgReader(Bytes{0x81, 0x2a, 0xa1, 'x'}).Decode() == Json({{"42", "x"}}), "Numeric map keys lost");
        Check(MsgReader(Bytes{0xd1, 0xff, 0x7f}).Decode() == -129, "Signed integer mismatch");
        Check(MsgReader(Bytes{0xca, 0x3f, 0xc0, 0, 0}).Decode() == 1.5, "Float32 mismatch");
        Check(ExpandLz4(Bytes{0x32, 'a', 'b', 'c', 3, 0}) == Bytes({'a','b','c','a','b','c','a','b','c'}), "Overlapping LZ4 mismatch");
        Bytes compressed{10, 1, 0, 1, 0, 6, 1, 0, 0, 3, 0x20, 0xa1, 'x'};
        Check(Decode(compressed).payload == "x", "Compressed frame mismatch");
        Check(ExpandCompressed(Bytes{0x28,0xb5,0x2f,0xfd,0x20,0x04,0x21,0,0,'t','e','s','t'}) == Bytes({'t','e','s','t'}), "Zstd raw-block golden frame mismatch");
        Bytes plain{'t','e','s','t'};
        Bytes lzframe(LZ4F_compressFrameBound(plain.size(), nullptr));
        auto lzsize = LZ4F_compressFrame(lzframe.data(), lzframe.size(), plain.data(), plain.size(), nullptr);
        Check(!LZ4F_isError(lzsize), "LZ4 frame fixture compression failed");
        lzframe.resize(lzsize);
        Check(ExpandCompressed(lzframe) == plain, "LZ4 frame decoding failed");
        Reject([] { ExpandCompressed(Bytes{0x28,0xb5,0x2f,0xfd,0x20,0x04,0x21,0,0,'t'}); });
        Reject([lzframe] { auto broken = lzframe; broken[6] ^= 0xff; ExpandCompressed(broken); });
        Reject([] { Decode({}); });
        Reject([] { auto b = Encode(1, 1, 6); b[0] = 11; Decode(b); });
        Reject([] { auto b = Encode(1, 1, 6); b.push_back(0); Decode(b); });
        Reject([] { auto b = Encode(1, 1, 6); b[9] = 1; Decode(b); });
        Reject([] { MsgReader(Bytes{0xdb, 255, 255, 255, 255}).Decode(); });
        Reject([] { MsgReader(Bytes{0xdd, 255, 255, 255, 255}).Decode(); });
        Reject([] { MsgReader(Bytes{0xcf, 1, 2}).Decode(); });
        Reject([] { MsgReader(Bytes{0x81, 0xc0, 0}).Decode(); });
        Reject([] { MsgReader(Bytes{0xc0, 0xc0}).Decode(); });
        Reject([] { MsgReader(Bytes(100, 0x91)).Decode(); });
        Reject([] { ExpandLz4(Bytes{0xf0}); });
        Reject([] { ExpandLz4(Bytes{0x40, 'x'}); });
        Reject([] { ExpandLz4(Bytes{0x10, 'x', 0}); });
        Reject([] { ExpandLz4(Bytes{0x10, 'x', 0, 0}); });
        Reject([] { ExpandLz4(Bytes{0x10, 'x', 2, 0}); });
        Reject([] { Bytes b{0x1f, 'x', 1, 0}; b.insert(b.end(), max_body / 255 + 1, 255); ExpandLz4(b); });
        std::mt19937 random(12345);
        for (int i = 0; i < 20000; ++i) {
            Bytes bytes(random() % 96);
            for (auto& value : bytes) value = uint8_t(random());
            try { MsgReader(bytes).Decode(); } catch (std::exception const&) {}
            try { ExpandLz4(bytes); } catch (std::exception const&) {}
        }
        std::cout << "PASS: " << checks << " protocol checks and 20000 malformed-input probes\n";
        return 0;
    } catch (std::exception const& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
