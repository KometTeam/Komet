#pragma once
#include "Session.h"
#include "Audio.h"
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.FileProperties.h>
#include <winrt/Windows.Web.Http.h>
#include <winrt/Windows.Web.Http.Headers.h>

namespace komet {
inline winrt::Windows::Foundation::Uri HttpsUri(std::string const& raw) {
    winrt::Windows::Foundation::Uri uri(winrt::to_hstring(raw));
    if (uri.SchemeName() != L"https" || uri.Host().empty() || !uri.UserName().empty() || !uri.Password().empty())
        throw std::runtime_error("Сервер вернул недопустимый HTTPS-адрес.");
    return uri;
}

inline Json UploadFile(std::shared_ptr<Session> const& session, winrt::Windows::Storage::StorageFile const& file, int64_t chat, int64_t cid) {
    using namespace winrt::Windows::Web::Http;
    auto properties = file.GetBasicPropertiesAsync().get();
    auto size = properties.Size();
    if (!size) throw std::runtime_error("Нельзя отправить пустой файл.");
    auto offer = session->Request(87, {{"count", 1}});
    auto items = Array(offer, "info");
    if (!items.is_array() || items.empty()) throw std::runtime_error("Сервер не вернул адрес загрузки.");
    auto item = items.front();
    auto input = file.OpenReadAsync().get();
    HttpStreamContent body(input);
    body.Headers().ContentLength(size);
    body.Headers().TryAppendWithoutValidation(L"Content-Type", L"application/x-binary; charset=x-user-defined");
    body.Headers().TryAppendWithoutValidation(L"Content-Range", L"bytes 0-" + winrt::to_hstring(size - 1) + L"/" + winrt::to_hstring(size));
    auto filename = winrt::to_string(file.Name());
    for (auto& c : filename) if (c == '\r' || c == '\n' || c == '"' || c == '\\') c = '_';
    body.Headers().TryAppendWithoutValidation(L"Content-Disposition", L"attachment; filename=\"" + winrt::to_hstring(filename) + L"\"");
    HttpClient client;
    client.DefaultRequestHeaders().UserAgent().TryParseAdd(L"OKMessages/26.23.2 (Android 14; Samsung Galaxy S24 Ultra; xxhdpi 450dpi 1440x3120)");
    auto response = client.PostAsync(HttpsUri(Text(item, "url")), body).get();
    response.EnsureSuccessStatusCode();
    Json attachment = {{"_type", "FILE"}};
    auto token = Text(item, "token");
    if (token.empty()) attachment["fileId"] = Integer(item, "fileId"); else attachment["token"] = token;
    Json request = {{"chatId", chat}, {"notify", true}, {"message", {{"cid", cid}, {"isLive", false},
        {"detectShare", false}, {"elements", Json::array()}, {"attaches", Json::array({attachment})}}}};
    for (int i = 0; i < 20; ++i) {
        try { return session->Request(64, request); }
        catch (std::exception const& error) {
            if (std::string(error.what()).find("not.ready") == std::string::npos || i == 19) throw;
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }
    throw std::runtime_error("Файл загружен, но сервер не подтвердил сообщение.");
}

inline std::string UploadPhoto(std::shared_ptr<Session> const& session, winrt::Windows::Storage::StorageFile const& file, bool avatar) {
    using namespace winrt::Windows::Web::Http;
    Json payload = {{"count", 1}};
    if (avatar) payload["profile"] = true;
    auto offer = session->Request(80, payload);
    auto input = file.OpenReadAsync().get();
    HttpStreamContent image(input);
    image.Headers().TryAppendWithoutValidation(L"Content-Type", file.ContentType());
    HttpMultipartFormDataContent content;
    content.Add(image, L"file", file.Name());
    HttpClient client;
    client.DefaultRequestHeaders().UserAgent().TryParseAdd(L"OKMessages/26.23.2 (Android 14; Samsung Galaxy S24 Ultra; xxhdpi 450dpi 1440x3120)");
    auto response = client.PostAsync(HttpsUri(Text(offer, "url")), content).get();
    response.EnsureSuccessStatusCode();
    auto raw = winrt::to_string(response.Content().ReadAsStringAsync().get());
    if (raw.size() > 1024 * 1024) throw std::runtime_error("Oversized photo response");
    auto data = Json::parse(raw);
    auto photos = Object(data, "photos");
    if (photos.is_object()) for (auto const& item : photos) {
        auto token = Text(item, "token");
        if (!token.empty()) return token;
    }
    auto token = Text(data, "photoToken");
    if (token.empty()) throw std::runtime_error("Сервер не вернул токен фотографии.");
    return token;
}

inline std::string AttachmentUrl(std::shared_ptr<Session> const& session, Json const& attach, int64_t chat, int64_t message) {
    auto type = Text(attach, "_type");
    if (type == "AUDIO") {
        auto url = FirstText(attach, {"url", "MP3"});
        if (!url.empty()) { HttpsUri(url); return url; }
    }
    if (type == "VIDEO") {
        auto data = session->Request(83, {{"chatId", chat}, {"messageId", message}, {"videoId", Integer(attach, "videoId")}, {"token", FirstText(attach, {"token", "videoToken"})}});
        for (auto key : {"MP4_360", "MP4_240", "MP4_480", "MP4_144", "MP4_720", "MP4_1080", "HLS", "EXTERNAL"}) {
            auto url = Text(data, key);
            if (!url.empty()) { HttpsUri(url); return url; }
        }
    }
    auto base = FirstText(attach, {"baseUrl", "url"});
    auto token = FirstText(attach, {"photoToken", "token"});
    Json payload;
    if (type == "FILE") payload = {{"fileId", Integer(attach, "fileId")}, {"chatId", chat}, {"messageId", message}, {"itemType", "REGULAR"}};
    else if (!base.empty() && !token.empty()) payload = {{"url", base}, {"token", token}};
    else if (!base.empty()) { HttpsUri(base); return base; }
    else throw std::runtime_error("Для этого вложения нет адреса загрузки.");
    auto data = session->Request(88, payload);
    auto url = FirstText(data, {"url", "content"});
    if (url.empty()) throw std::runtime_error("Сервер не вернул ссылку вложения.");
    HttpsUri(url);
    return url;
}

inline winrt::Windows::Storage::StorageFile DecodeVoice(std::string const& url) {
    using namespace winrt::Windows::Storage;
    using namespace winrt::Windows::Storage::Streams;
    using namespace winrt::Windows::Web::Http;
    HttpClient client;
    auto response = client.GetAsync(HttpsUri(url), HttpCompletionOption::ResponseHeadersRead).get();
    response.EnsureSuccessStatusCode();
    auto size = response.Content().Headers().ContentLength();
    constexpr size_t limit = 16 * 1024 * 1024;
    if (size && size.Value() > limit) throw std::runtime_error("Аудиофайл слишком большой.");
    DataReader reader(response.Content().ReadAsInputStreamAsync().get());
    reader.InputStreamOptions(InputStreamOptions::Partial);
    Bytes input;
    for (;;) {
        auto count = reader.LoadAsync(65536).get();
        if (!count) break;
        if (input.size() + count > limit) throw std::runtime_error("Аудиофайл слишком большой.");
        Bytes chunk(count);
        reader.ReadBytes(chunk);
        input.insert(input.end(), chunk.begin(), chunk.end());
    }
    bool ogg = input.size() >= 4 && std::memcmp(input.data(), "OggS", 4) == 0;
    auto filename = ogg ? L"voice.wav" : input.size() >= 12 && std::memcmp(input.data(), "RIFF", 4) == 0 ? L"audio.wav" : input.size() >= 12 && std::memcmp(input.data() + 4, "ftyp", 4) == 0 ? L"audio.m4a" : L"audio.mp3";
    auto file = ApplicationData::Current().TemporaryFolder().CreateFileAsync(filename, CreationCollisionOption::GenerateUniqueName).get();
    try {
        auto stream = file.OpenAsync(FileAccessMode::ReadWrite).get();
        DataWriter writer(stream);
        auto write = [&](Bytes const& bytes) { writer.WriteBytes(bytes); writer.StoreAsync().get(); };
        if (ogg) DecodeOpusWave(input, write);
        else write(input);
        writer.FlushAsync().get();
        writer.DetachStream();
        stream.Close();
    } catch (...) {
        try { file.DeleteAsync().get(); } catch (...) {}
        throw;
    }
    return file;
}

inline void DownloadTo(std::string const& url, winrt::Windows::Storage::StorageFile const& target) {
    using namespace winrt::Windows::Storage::Streams;
    winrt::Windows::Web::Http::HttpClient client;
    auto input = client.GetInputStreamAsync(HttpsUri(url)).get();
    auto output = target.OpenAsync(winrt::Windows::Storage::FileAccessMode::ReadWrite).get();
    output.Size(0);
    RandomAccessStream::CopyAsync(input, output).get();
    output.FlushAsync().get();
}
}
