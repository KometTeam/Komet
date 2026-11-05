#include <windows.h>
#undef GetCurrentTime
#include "../app/Images.h"
#include <iostream>

int main() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
        komet::Bytes fixture{82,73,70,70,30,0,0,0,87,69,66,80,86,80,56,76,17,0,0,0,47,2,64,0,16,7,80,138,194,87,161,128,129,136,232,127,0,0};
        if (komet::FirstText({{"baseUrl", ""}, {"iconUrl", "https://synthetic.invalid/icon"}}, {"baseUrl", "iconUrl"}) != "https://synthetic.invalid/icon") throw std::runtime_error("Empty primary URL masked fallback");
        auto decoded = komet::DecodeImagePixels(fixture, 96);
        if (decoded.width != 3 || decoded.height != 2 || decoded.bytes.size() != 24 || decoded.bytes[3] != 128 || std::abs(int(decoded.bytes[2]) - 120) > 1) throw std::runtime_error("Windows decode/premultiplication failed");
        if (komet::AttachmentPreview({{"previewData", komet::Json::binary(fixture)}}) != fixture) throw std::runtime_error("Binary preview lost");
        if (komet::AttachmentPreview(komet::Json::parse(komet::Json{{"previewData", komet::Json::binary(fixture)}}.dump())) != fixture) throw std::runtime_error("Cached binary preview lost");
        if (komet::AttachmentPreview({{"previewData", fixture}}) != fixture) throw std::runtime_error("Array preview lost");
        auto buffer = winrt::Windows::Security::Cryptography::CryptographicBuffer::CreateFromByteArray(fixture);
        auto encoded = winrt::Windows::Security::Cryptography::CryptographicBuffer::EncodeToBase64String(buffer);
        if (komet::AttachmentPreview({{"previewData", "data:image/webp;base64," + winrt::to_string(encoded)}}) != fixture) throw std::runtime_error("Data URI preview lost");
        if (!komet::AttachmentPreview({{"previewData", komet::Json::array({-1, 999})}}).empty()) throw std::runtime_error("Invalid preview accepted");
        komet::Bytes png_fixture{137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,3,0,0,0,2,8,6,0,0,0,157,116,102,26,0,0,0,20,73,68,65,84,120,156,99,252,32,194,213,192,0,5,76,48,6,136,6,0,37,132,1,146,222,203,158,13,0,0,0,0,73,69,78,68,174,66,96,130};
        auto png_pixels = komet::DecodeImagePixels(png_fixture, 96);
        if (png_pixels.width != 3 || png_pixels.height != 2 || png_pixels.bytes[3] != 128) throw std::runtime_error("PNG pipeline failed");
        komet::Bytes jpeg_fixture{255,216,255,224,0,16,74,70,73,70,0,1,1,0,0,1,0,1,0,0,255,225,0,34,69,120,105,102,0,0,77,77,0,42,0,0,0,8,0,1,1,18,0,3,0,0,0,1,0,6,0,0,0,0,0,0,255,219,0,67,0,2,1,1,1,1,1,2,1,1,1,2,2,2,2,2,4,3,2,2,2,2,5,4,4,3,4,6,5,6,6,6,5,6,6,6,7,9,8,6,7,9,7,6,6,8,11,8,9,10,10,10,10,10,6,8,11,12,11,10,12,9,10,10,10,255,219,0,67,1,2,2,2,2,2,2,5,3,3,5,10,7,6,7,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,255,192,0,17,8,0,2,0,3,3,1,34,0,2,17,1,3,17,1,255,196,0,31,0,0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,255,196,0,181,16,0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,125,1,2,3,0,4,17,5,18,33,49,65,6,19,81,97,7,34,113,20,50,129,145,161,8,35,66,177,193,21,82,209,240,36,51,98,114,130,9,10,22,23,24,25,26,37,38,39,40,41,42,52,53,54,55,56,57,58,67,68,69,70,71,72,73,74,83,84,85,86,87,88,89,90,99,100,101,102,103,104,105,106,115,116,117,118,119,120,121,122,131,132,133,134,135,136,137,138,146,147,148,149,150,151,152,153,154,162,163,164,165,166,167,168,169,170,178,179,180,181,182,183,184,185,186,194,195,196,197,198,199,200,201,202,210,211,212,213,214,215,216,217,218,225,226,227,228,229,230,231,232,233,234,241,242,243,244,245,246,247,248,249,250,255,196,0,31,1,0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,255,196,0,181,17,0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,119,0,1,2,3,17,4,5,33,49,6,18,65,81,7,97,113,19,34,50,129,8,20,66,145,161,177,193,9,35,51,82,240,21,98,114,209,10,22,36,52,225,37,241,23,24,25,26,38,39,40,41,42,53,54,55,56,57,58,67,68,69,70,71,72,73,74,83,84,85,86,87,88,89,90,99,100,101,102,103,104,105,106,115,116,117,118,119,120,121,122,130,131,132,133,134,135,136,137,138,146,147,148,149,150,151,152,153,154,162,163,164,165,166,167,168,169,170,178,179,180,181,182,183,184,185,186,194,195,196,197,198,199,200,201,202,210,211,212,213,214,215,216,217,218,226,227,228,229,230,231,232,233,234,242,243,244,245,246,247,248,249,250,255,218,0,12,3,1,0,2,17,3,17,0,63,0,249,78,138,40,175,229,115,253,188,63,255,217};
        auto jpeg_pixels = komet::DecodeImagePixels(jpeg_fixture, 96);
        if (jpeg_pixels.width != 2 || jpeg_pixels.height != 3 || jpeg_pixels.bytes[3] != 255) throw std::runtime_error("JPEG orientation pipeline failed");
        auto bmp = komet::CompatibleImage(fixture, 96);
        if (bmp.size() != 146 || bmp[0] != 'B' || bmp[1] != 'M' || bmp[18] != 3 || bmp[122] != 10 || bmp[123] != 20 || bmp[124] != 240 || bmp[125] != 128) throw std::runtime_error("WebP BGRA or alpha mismatch");
        auto scaled = komet::CompatibleImage(fixture, 1);
        if (scaled[18] != 1 || scaled.size() != 126) throw std::runtime_error("WebP scaling mismatch");
        komet::Bytes png{137,80,78,71};
        if (komet::CompatibleImage(png, 48) != png) throw std::runtime_error("Native image modified");
        fixture.resize(20);
        bool rejected = false;
        try { komet::CompatibleImage(fixture, 96); } catch (...) { rejected = true; }
        if (!rejected) throw std::runtime_error("Broken WebP accepted");
        std::cout << "PASS: Windows JPEG/PNG/WebP decode, EXIF rotation, premultiplied alpha, binary/array previews, scaling, corrupt-input rejection\n";
        return 0;
    } catch (std::exception const& e) { std::cerr << e.what() << '\n'; return 1; }
}
