#pragma once
#include "Media.h"
#include "../third_party/webp/src/webp/decode.h"
#include <winrt/Windows.UI.Xaml.Media.Imaging.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Security.Cryptography.h>

namespace komet {
inline Bytes ImageBytes(std::string const& url) {
    struct Store {
        std::mutex mutex;
        std::condition_variable ready;
        int active = 0;
        size_t size = 0;
        std::map<std::string, Bytes> cache;
    };
    static Store store;
    std::unique_lock<std::mutex> lock(store.mutex);
    store.ready.wait(lock, [&] { return store.active < 2; });
    auto cached = store.cache.find(url);
    if (cached != store.cache.end()) return cached->second;
    ++store.active;
    lock.unlock();
    struct Release {
        Store& store;
        ~Release() { std::lock_guard<std::mutex> lock(store.mutex); --store.active; store.ready.notify_one(); }
    } release{store};
    using namespace winrt::Windows::Web::Http;
    using namespace winrt::Windows::Storage::Streams;
    HttpClient client;
    client.DefaultRequestHeaders().UserAgent().TryParseAdd(L"OKMessages/26.23.2 (Android 14)");
    client.DefaultRequestHeaders().TryAppendWithoutValidation(L"Accept", L"image/jpeg,image/png,image/webp,image/*;q=0.8");
    auto operation = client.GetAsync(HttpsUri(url), HttpCompletionOption::ResponseHeadersRead);
    if (operation.wait_for(std::chrono::seconds(25)) == winrt::Windows::Foundation::AsyncStatus::Started) { operation.Cancel(); throw std::runtime_error("Сервер изображения не ответил."); }
    auto response = operation.get();
    response.EnsureSuccessStatusCode();
    DataReader reader(response.Content().ReadAsInputStreamAsync().get());
    reader.InputStreamOptions(InputStreamOptions::Partial);
    Bytes bytes;
    for (;;) {
        auto read = reader.LoadAsync(65536);
        if (read.wait_for(std::chrono::seconds(25)) == winrt::Windows::Foundation::AsyncStatus::Started) { read.Cancel(); throw std::runtime_error("Загрузка изображения прервана."); }
        auto count = read.get();
        if (!count) break;
        if (bytes.size() + count > 12 * 1024 * 1024) throw std::runtime_error("Изображение слишком большое.");
        Bytes chunk(count); reader.ReadBytes(chunk);
        bytes.insert(bytes.end(), chunk.begin(), chunk.end());
    }
    if (bytes.size() <= 2 * 1024 * 1024) {
        std::lock_guard<std::mutex> cache_lock(store.mutex);
        if (!store.cache.count(url)) {
            while (!store.cache.empty() && store.size + bytes.size() > 8 * 1024 * 1024) { store.size -= store.cache.begin()->second.size(); store.cache.erase(store.cache.begin()); }
            store.size += bytes.size();
            store.cache.emplace(url, bytes);
        }
    }
    return bytes;
}

inline Bytes CompatibleImage(Bytes bytes, int width) {
    if (bytes.size() < 12 || std::memcmp(bytes.data(), "RIFF", 4) || std::memcmp(bytes.data() + 8, "WEBP", 4)) return bytes;
    WebPDecoderConfig config;
    if (!WebPInitDecoderConfig(&config) || WebPGetFeatures(bytes.data(), bytes.size(), &config.input) != VP8_STATUS_OK) throw std::runtime_error("Повреждённое изображение WebP.");
    if (config.input.width <= 0 || config.input.height <= 0 || int64_t(config.input.width) * config.input.height > 64000000) throw std::runtime_error("Недопустимый размер WebP.");
    auto target_width = std::min(config.input.width, std::max(1, width));
    auto target_height = std::max(1, int(int64_t(config.input.height) * target_width / config.input.width));
    if (int64_t(target_width) * target_height > 4000000) throw std::runtime_error("Изображение слишком высокое.");
    config.options.use_scaling = target_width != config.input.width;
    config.options.scaled_width = target_width;
    config.options.scaled_height = target_height;
    config.output.colorspace = MODE_BGRA;
    Bytes bitmap(122 + size_t(target_width) * target_height * 4, 0);
    config.output.is_external_memory = 1;
    config.output.u.RGBA.rgba = bitmap.data() + 122;
    config.output.u.RGBA.stride = target_width * 4;
    config.output.u.RGBA.size = bitmap.size() - 122;
    auto status = WebPDecode(bytes.data(), bytes.size(), &config);
    WebPFreeDecBuffer(&config.output);
    if (status != VP8_STATUS_OK) throw std::runtime_error("Не удалось декодировать WebP.");
    auto put = [&](size_t at, uint32_t value, size_t count) { while (count--) { bitmap[at++] = uint8_t(value); value >>= 8; } };
    bitmap[0] = 'B'; bitmap[1] = 'M';
    put(2, uint32_t(bitmap.size()), 4); put(10, 122, 4); put(14, 108, 4);
    put(18, target_width, 4); put(22, uint32_t(-target_height), 4); put(26, 1, 2); put(28, 32, 2); put(30, 3, 4);
    put(34, uint32_t(bitmap.size() - 122), 4);
    put(54, 0x00ff0000, 4); put(58, 0x0000ff00, 4); put(62, 0x000000ff, 4); put(66, 0xff000000, 4); put(70, 0x73524742, 4);
    return bitmap;
}

struct ImagePixels {
    uint32_t width = 0;
    uint32_t height = 0;
    winrt::com_array<uint8_t> bytes;
};

inline ImagePixels DecodeImagePixels(Bytes bytes, int width) {
    using namespace winrt::Windows::Storage::Streams;
    using namespace winrt::Windows::Graphics::Imaging;
    if (bytes.empty() || bytes.size() > 12 * 1024 * 1024) throw std::runtime_error("Пустое или слишком большое изображение.");
    bytes = CompatibleImage(std::move(bytes), width);
    InMemoryRandomAccessStream stream;
    DataWriter writer(stream);
    writer.WriteBytes(bytes); writer.StoreAsync().get(); writer.DetachStream(); stream.Seek(0);
    auto decoder = BitmapDecoder::CreateAsync(stream).get();
    auto original_width = decoder.OrientedPixelWidth();
    auto original_height = decoder.OrientedPixelHeight();
    if (!original_width || !original_height || uint64_t(original_width) * original_height > 64000000) throw std::runtime_error("Недопустимый размер изображения.");
    auto scale = std::min(1.0, double(std::max(1, width)) / original_width);
    BitmapTransform transform;
    transform.ScaledWidth(std::max(1u, uint32_t(decoder.PixelWidth() * scale)));
    transform.ScaledHeight(std::max(1u, uint32_t(decoder.PixelHeight() * scale)));
    bool swap = decoder.PixelWidth() != original_width;
    ImagePixels pixels;
    pixels.width = swap ? transform.ScaledHeight() : transform.ScaledWidth();
    pixels.height = swap ? transform.ScaledWidth() : transform.ScaledHeight();
    if (uint64_t(pixels.width) * pixels.height > 4000000) throw std::runtime_error("Изображение слишком высокое.");
    auto provider = decoder.GetPixelDataAsync(BitmapPixelFormat::Bgra8, BitmapAlphaMode::Premultiplied, transform, ExifOrientationMode::RespectExifOrientation, ColorManagementMode::ColorManageToSRgb).get();
    pixels.bytes = provider.DetachPixelData();
    if (pixels.bytes.size() != size_t(pixels.width) * pixels.height * 4) throw std::runtime_error("Некорректный буфер изображения.");
    return pixels;
}

inline Bytes AttachmentPreview(Json const& attachment) {
    auto it = attachment.find("previewData");
    if (it == attachment.end()) return {};
    if (it->is_binary()) return it->get_binary();
    if (it->is_object() && it->contains("bytes") && it->at("bytes").is_array()) return AttachmentPreview(Json{{"previewData", it->at("bytes")}});
    if (it->is_array()) {
        if (it->size() > 1024 * 1024) return {};
        Bytes bytes;
        for (auto const& value : *it) {
            if (!value.is_number_integer()) return {};
            auto number = value.get<int>();
            if (number < 0 || number > 255) return {};
            bytes.push_back(uint8_t(number));
        }
        return bytes;
    }
    if (it->is_string()) {
        auto raw = it->get<std::string>();
        if (raw.size() > 1500000 || raw.compare(0, 11, "data:image/") != 0) return {};
        auto comma = raw.find(',');
        if (comma == std::string::npos || raw.substr(0, comma).find(";base64") == std::string::npos) return {};
        try {
            auto buffer = winrt::Windows::Security::Cryptography::CryptographicBuffer::DecodeFromBase64String(winrt::to_hstring(raw.substr(comma + 1)));
            Bytes bytes(buffer.Length());
            auto reader = winrt::Windows::Storage::Streams::DataReader::FromBuffer(buffer); reader.ReadBytes(bytes);
            return bytes;
        } catch (...) {}
    }
    return {};
}

inline winrt::fire_and_forget LoadImage(std::string url, Bytes bytes, int width, std::function<void(winrt::Windows::UI::Xaml::Media::ImageSource, winrt::hstring)> done) {
    winrt::apartment_context ui;
    winrt::hstring error;
    ImagePixels pixels;
    std::wstring stage = bytes.empty() ? L"HTTP" : L"Превью";
    try {
        co_await winrt::resume_background();
        if (bytes.empty()) bytes = ImageBytes(url);
        stage = L"Декодирование";
        pixels = DecodeImagePixels(std::move(bytes), width);
    } catch (winrt::hresult_error const& e) { error = winrt::hstring(stage) + L": " + e.message() + L" (" + winrt::to_hstring(int32_t(e.code())) + L")"; }
    catch (std::exception const& e) { error = winrt::hstring(stage) + L": " + winrt::to_hstring(e.what()); }
    co_await ui;
    winrt::Windows::UI::Xaml::Media::ImageSource source{nullptr};
    if (error.empty()) {
        try {
            winrt::Windows::UI::Xaml::Media::Imaging::WriteableBitmap bitmap(int(pixels.width), int(pixels.height));
            std::memcpy(bitmap.PixelBuffer().data(), pixels.bytes.data(), pixels.bytes.size());
            bitmap.Invalidate();
            source = bitmap;
        } catch (winrt::hresult_error const& e) { error = L"Отображение: " + e.message() + L" (" + winrt::to_hstring(int32_t(e.code())) + L")"; }
    }
    if (!error.empty()) {
        try { winrt::Windows::Storage::ApplicationData::Current().LocalSettings().Values().Insert(L"lastImageError", winrt::box_value(error)); } catch (...) {}
    }
    try { done(source, error); } catch (...) {}
}
}
