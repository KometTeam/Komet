#include <windows.h>
#include "../app/Certificate.h"
#include <iostream>

int main() {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    try {
        using namespace winrt::Windows::Networking;
        using namespace winrt::Windows::Networking::Sockets;
        StreamSocket socket;
        socket.Control().IgnorableServerCertificateErrors().Append(
            winrt::Windows::Security::Cryptography::Certificates::ChainValidationResult::Untrusted);
        socket.ConnectAsync(HostName(L"api2.oneme.ru"), L"443", SocketProtectionLevel::Tls12).get();
        komet::ValidateNativeCertificate(socket.Information(), L"api2.oneme.ru");
        bool rejected = false;
        try { komet::ValidateNativeCertificate(socket.Information(), L"synthetic.invalid"); }
        catch (winrt::hresult_error const& error) { rejected = uint32_t(error.code()) == uint32_t(CERT_E_CN_NO_MATCH); }
        socket.Close();
        if (!rejected) throw std::runtime_error("Certificate hostname mismatch was not rejected by SSL policy");
        std::cout << "PASS: primary custom CA chain accepted; wrong DNS name rejected\n";
        return 0;
    } catch (winrt::hresult_error const& error) { std::cerr << "TLS error " << int32_t(error.code()) << ": " << winrt::to_string(error.message()) << '\n'; }
    catch (std::exception const& error) { std::cerr << error.what() << '\n'; }
    return 1;
}
