#pragma once
#include "Protocol.h"
#include <winrt/Windows.Security.Cryptography.h>
#include <winrt/Windows.Security.Cryptography.Core.h>
#include <winrt/Windows.Storage.Streams.h>

namespace komet {
inline Bytes Fingerprint(int64_t seed, std::string const& device) {
    using namespace winrt::Windows::Security::Cryptography;
    using namespace winrt::Windows::Security::Cryptography::Core;
    auto provider = HashAlgorithmProvider::OpenAlgorithm(HashAlgorithmNames::Sha256());
    Bytes result;
    for (auto hex : {"1684414033eb263e2c615f8b7df5ed8793850a07656304997fbf07e9e21e1e93",
                     "38cff46f392dc1734c308be011c2f0d8da152a390b41063dbb2c913e3032f4b3",
                     "634ecc42b246784d975f180b4fecf903df235cdf0476da47163a85630eb1a6a8"}) {
        Bytes input;
        for (size_t i = 0; i < 64; i += 2) input.push_back(uint8_t(std::stoul(std::string(hex + i, 2), nullptr, 16)));
        for (int shift = 56; shift >= 0; shift -= 8) input.push_back(uint8_t(uint64_t(seed) >> shift));
        input.insert(input.end(), device.begin(), device.end());
        auto hash = provider.HashData(CryptographicBuffer::CreateFromByteArray(input));
        winrt::com_array<uint8_t> bytes;
        CryptographicBuffer::CopyToByteArray(hash, bytes);
        result.insert(result.end(), bytes.begin(), bytes.end());
    }
    return result;
}

inline Json NativeHandshake(std::string const& device, std::string const& instance, int64_t session) {
    return {{"deviceId", device}, {"mt_instanceid", instance}, {"clientSessionId", session}, {"userAgent", {
        {"deviceType", "ANDROID"}, {"appVersion", "26.23.2"}, {"buildNumber", 6779},
        {"osVersion", "Android 14"}, {"deviceName", "Samsung Galaxy S24 Ultra"},
        {"arch", "arm64-v8a"}, {"screen", "xxhdpi 450dpi 1440x3120"},
        {"timezone", "Asia/Omsk"}, {"locale", "ru"}, {"deviceLocale", "ru"}, {"pushDeviceType", "GCM"}}}};
}

inline std::string NormalizePhone(std::string const& raw) {
    std::string phone = "+";
    for (auto c : raw) if (c >= '0' && c <= '9') phone += c;
    if (phone.size() < 9 || phone.size() > 16) throw std::runtime_error("Введите номер с кодом страны, например +7…");
    return phone;
}

inline std::string NormalizeCode(std::string const& raw, size_t count = 6) {
    std::string code;
    for (auto c : raw) {
        if (c >= '0' && c <= '9') code += c;
        else if (c != ' ' && c != '-' && c != '\t' && c != '\r' && c != '\n')
            throw std::runtime_error("Введите только цифры кода подтверждения.");
    }
    if (code.size() != count) throw std::runtime_error("Введите код полностью: " + std::to_string(count) + " цифр.");
    return code;
}

inline int64_t AccountId(Json const& response) {
    auto profile = Object(response, "profile");
    auto contact = Object(profile, "contact");
    auto id = Integer(contact, "id", Integer(contact, "contactId", Integer(contact, "accountId")));
    if (id) return id;
    id = Integer(profile, "id", Integer(profile, "accountId"));
    if (id) return id;
    contact = Object(response, "contact");
    id = Integer(contact, "id", Integer(contact, "contactId"));
    if (id) return id;
    auto account = Object(response, "account");
    return Integer(account, "id", Integer(account, "accountId", Integer(response, "accountId", Integer(response, "account_id"))));
}

inline Json LoginPayload(std::string const& token, bool native, bool interactive, Bytes const& fingerprint = {}) {
    if (native) return {{"token", token}, {"interactive", interactive}, {"presenceSync", -1}, {"chatsSync", -1},
        {"exp", {{"chatsCountGroups", Json::binary(Bytes{0x0b, 0x32})}}}, {"chatCacheFingerprint", Json::binary(fingerprint)}};
    return {{"token", token}, {"chatsCount", 50}, {"interactive", interactive}, {"chatsSync", 0},
        {"contactsSync", 0}, {"presenceSync", -1}, {"draftsSync", 0}};
}

inline std::string DeliveryStatus(Json const& data) {
    auto type = Text(data, "codeType", Text(data, "deliveryType", Text(data, "type")));
    if (type == "SMS") return "Сервер выбрал SMS. Ожидайте код на телефоне.";
    if (type == "ONEME" || type == "MAX" || type == "IN_APP") return "Сервер отправляет код в MAX. Проверьте приложение на другом устройстве.";
    if (type == "CALL" || type == "PHONE_CALL") return "Сервер выбрал подтверждение звонком.";
    return "Сервер принял запрос кода. Проверьте MAX и SMS; доставка SMS ещё не подтверждена.";
}
}
