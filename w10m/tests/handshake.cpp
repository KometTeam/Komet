#include <windows.h>
#include "../app/Session.h"
#include <iostream>

int main() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
        GUID id;
        winrt::check_hresult(CoCreateGuid(&id));
        auto device = winrt::to_string(winrt::to_hstring(id));
        device = device.substr(1, device.size() - 2);
        for (auto mode : {0, 1}) {
            bool native = mode != 0;
            auto session = std::make_shared<komet::Session>();
            auto result = session->Connect(device, native, mode != 2);
            if (!result.is_object()) throw std::runtime_error("Expected handshake object");
            if (native && !result.contains("callsSeed")) throw std::runtime_error("Native handshake omitted callsSeed");
            session->Request(1, {{"interactive", false}});
            session->Close();
            std::cout << "PASS: unauthenticated SESSION_INIT and PING over " << (mode == 0 ? "WebSocket" : mode == 1 ? "primary api2 TLS with explicit CA validation" : "legacy api TLS") << '\n';
        }
        return 0;
    } catch (winrt::hresult_error const& e) {
        std::cerr << "Windows error " << int32_t(e.code()) << ": " << winrt::to_string(e.message()) << '\n';
    } catch (std::exception const& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
