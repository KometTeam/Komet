#pragma once
#include "Protocol.h"
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.FileProperties.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Security.Cryptography.h>
#include <winrt/Windows.Security.Cryptography.DataProtection.h>
#include <mutex>
#include <atomic>

namespace komet {
struct Cache {
    static std::mutex& Mutex() { static std::mutex mutex; return mutex; }
    static std::atomic<uint64_t>& Epoch() { static std::atomic<uint64_t> epoch{0}; return epoch; }
    static void Invalidate() { ++Epoch(); }
    static void Write(Json const& snapshot, uint64_t epoch) {
        using namespace winrt::Windows::Storage;
        using namespace winrt::Windows::Security::Cryptography;
        std::lock_guard<std::mutex> lock(Mutex());
        if (Epoch().load() != epoch) return;
        auto text = snapshot.dump();
        if (text.size() > 8 * 1024 * 1024) throw std::runtime_error("Cache size limit");
        auto input = CryptographicBuffer::ConvertStringToBinary(winrt::to_hstring(text), BinaryStringEncoding::Utf8);
        DataProtection::DataProtectionProvider protection(L"LOCAL=user");
        auto encrypted = protection.ProtectAsync(input).get();
        auto folder = ApplicationData::Current().LocalFolder();
        auto file = folder.CreateFileAsync(L"cache-new.bin", CreationCollisionOption::ReplaceExisting).get();
        FileIO::WriteBufferAsync(file, encrypted).get();
        file.RenameAsync(L"cache.bin", NameCollisionOption::ReplaceExisting).get();
    }
    static Json Read() {
        using namespace winrt::Windows::Storage;
        using namespace winrt::Windows::Security::Cryptography;
        std::lock_guard<std::mutex> lock(Mutex());
        auto folder = ApplicationData::Current().LocalFolder();
        auto item = folder.TryGetItemAsync(L"cache.bin").get();
        if (!item) return nullptr;
        auto file = item.as<StorageFile>();
        if (file.GetBasicPropertiesAsync().get().Size() > 10 * 1024 * 1024) throw std::runtime_error("Cache size limit");
        DataProtection::DataProtectionProvider protection;
        auto data = protection.UnprotectAsync(FileIO::ReadBufferAsync(file).get()).get();
        auto text = CryptographicBuffer::ConvertBinaryToString(BinaryStringEncoding::Utf8, data);
        return Json::parse(winrt::to_string(text));
    }
    static void Clear() {
        Invalidate();
        std::lock_guard<std::mutex> lock(Mutex());
        auto folder = winrt::Windows::Storage::ApplicationData::Current().LocalFolder();
        auto item = folder.TryGetItemAsync(L"cache.bin").get();
        if (item) item.DeleteAsync().get();
    }
};
}
