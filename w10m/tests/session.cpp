#include <windows.h>
#include "../app/Session.h"
#include <iostream>
#include <atomic>

int main(int argc, char** argv) {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
        if (argc != 2) throw std::runtime_error("Loopback endpoint required");
        auto session = std::make_shared<komet::Session>();
        std::atomic<int> disconnected{0};
        session->OnDisconnected([&] { ++disconnected; });
        session->Connect("synthetic-id", false, true, winrt::Windows::Foundation::Uri(winrt::to_hstring(argv[1])));
        std::cout << "Loopback handshake complete; testing 46-second idle with unanswered pings" << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(46));
        session->Ping(false);
        session->Request(49, {{"chatId", 1234}});
        bool timed_out = false;
        try { session->Request(87); } catch (std::runtime_error const&) { timed_out = true; }
        if (!timed_out) throw std::runtime_error("Missing request timeout");
        session->Request(49, {{"chatId", 1234}});
        if (disconnected) throw std::runtime_error("Idle or unrelated request timeout disconnected healthy socket");
        session->OnDisconnected(nullptr);
        session->Close();
        std::cout << "PASS: idle without ping acknowledgements and individual request timeout preserve working session" << std::endl;
        return 0;
    } catch (winrt::hresult_error const& e) { std::cerr << winrt::to_string(e.message()) << '\n'; }
    catch (std::exception const& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
