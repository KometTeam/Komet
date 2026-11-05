#include <windows.h>
#include "../app/Auth.h"
#include <iostream>

int main() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
        auto bytes = komet::Fingerprint(-12345, "synthetic-device");
        auto encoded = winrt::Windows::Security::Cryptography::CryptographicBuffer::EncodeToHexString(
            winrt::Windows::Security::Cryptography::CryptographicBuffer::CreateFromByteArray(bytes));
        if (winrt::to_string(encoded) != "e1988cb4b988ca528dd957188888ecdfbe2b1d58de896791046aaac17371be1cd5d44d884cff26eec7eea1b2ab21f80ce1c05b304064f6bb5baec13d7b41d90f26a7b3d87460b137de87a7fd7d6511826085b56f9cc9c205eab7c2b3a818e887")
            throw std::runtime_error("Fingerprint differs from independent SHA256 vector");
        auto binary = komet::Decode(komet::Encode(0, 1, 17, {{"mode", komet::Json::binary(bytes)}})).payload.at("mode");
        if (!binary.is_binary() || binary.get_binary().size() != 96) throw std::runtime_error("Fingerprint wire type mismatch");
        if (komet::NormalizePhone("+7 (000) 000-00-00") != "+70000000000") throw std::runtime_error("Phone normalization failed");
        if (komet::NormalizeCode(" 123-456 ") != "123456") throw std::runtime_error("OTP normalization failed");
        if (komet::AccountId({{"profile", {{"contact", {{"contactId", "123456"}}}}}}) != 123456) throw std::runtime_error("Alternate account shape failed");
        auto login = komet::LoginPayload("synthetic-token", true, false, bytes);
        if (login.at("chatsSync") != -1 || login.at("presenceSync") != -1 || login.contains("contactsSync") || login.contains("chatsCount") || login.at("interactive") != false)
            throw std::runtime_error("Native LOGIN differs from original first-login contract");
        auto result = komet::DeliveryStatus({{"token", "synthetic-token"}});
        if (result.find("synthetic-token") != std::string::npos) throw std::runtime_error("Auth token leaked to UI");
        std::cout << "PASS: fingerprint golden vector, binary wire shape, phone/OTP normalization, account shape, native LOGIN contract, auth status redaction\n";
        return 0;
    } catch (std::exception const& error) { std::cerr << error.what() << '\n'; }
    return 1;
}
