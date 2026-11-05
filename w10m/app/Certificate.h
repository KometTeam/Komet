#pragma once
#include <windows.h>
#include <wincrypt.h>
#include "NativeRoots.h"
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Networking.h>
#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Security.Cryptography.h>
#include <winrt/Windows.Security.Cryptography.Certificates.h>
#include <winrt/Windows.Storage.Streams.h>

#pragma comment(lib, "Crypt32.lib")

namespace komet {
struct CertificateStoreHandle {
    HCERTSTORE value = CertOpenStore(CERT_STORE_PROV_MEMORY, 0, 0, CERT_STORE_CREATE_NEW_FLAG, nullptr);
    CertificateStoreHandle() { if (!value) winrt::throw_last_error(); }
    ~CertificateStoreHandle() { CertCloseStore(value, 0); }
    void Add(winrt::Windows::Storage::Streams::IBuffer const& buffer) {
        winrt::com_array<uint8_t> bytes;
        winrt::Windows::Security::Cryptography::CryptographicBuffer::CopyToByteArray(buffer, bytes);
        if (!CertAddEncodedCertificateToStore(value, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, bytes.data(), bytes.size(), CERT_STORE_ADD_USE_EXISTING, nullptr))
            winrt::throw_last_error();
    }
};

inline void ValidateNativeCertificate(winrt::Windows::Networking::Sockets::StreamSocketInformation const& info, winrt::hstring const& host) {
    using namespace winrt::Windows::Security::Cryptography;
    auto certificate = info.ServerCertificate();
    if (!certificate) throw std::runtime_error("Сервер не предоставил сертификат TLS.");
    CertificateStoreHandle roots;
    roots.Add(CryptographicBuffer::DecodeFromBase64String(native_root));
    CertificateStoreHandle extra;
    extra.Add(CryptographicBuffer::DecodeFromBase64String(native_intermediate));
    for (auto const& item : info.ServerIntermediateCertificates()) extra.Add(item.GetCertificateBlob());
    winrt::com_array<uint8_t> leafBytes;
    CryptographicBuffer::CopyToByteArray(certificate.GetCertificateBlob(), leafBytes);
    struct Context {
        PCCERT_CONTEXT value;
        ~Context() { if (value) CertFreeCertificateContext(value); }
    } leaf{CertCreateCertificateContext(X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, leafBytes.data(), leafBytes.size())};
    if (!leaf.value) winrt::throw_last_error();
    CERT_CHAIN_ENGINE_CONFIG configuration{};
    configuration.cbSize = sizeof(configuration);
    configuration.hExclusiveRoot = roots.value;
    struct Engine {
        HCERTCHAINENGINE value = nullptr;
        ~Engine() { if (value) CertFreeCertificateChainEngine(value); }
    } engine;
    if (!CertCreateCertificateChainEngine(&configuration, &engine.value)) winrt::throw_last_error();
    CERT_CHAIN_PARA parameters{};
    parameters.cbSize = sizeof(parameters);
    parameters.RequestedUsage.dwType = USAGE_MATCH_TYPE_AND;
    LPSTR usage = const_cast<LPSTR>(szOID_PKIX_KP_SERVER_AUTH);
    parameters.RequestedUsage.Usage.cUsageIdentifier = 1;
    parameters.RequestedUsage.Usage.rgpszUsageIdentifier = &usage;
    struct Chain {
        PCCERT_CHAIN_CONTEXT value = nullptr;
        ~Chain() { if (value) CertFreeCertificateChain(value); }
    } chain;
    if (!CertGetCertificateChain(engine.value, leaf.value, nullptr, extra.value, &parameters,
        CERT_CHAIN_CACHE_ONLY_URL_RETRIEVAL, nullptr, &chain.value)) winrt::throw_last_error();
    SSL_EXTRA_CERT_CHAIN_POLICY_PARA ssl{};
    ssl.cbSize = sizeof(ssl);
    ssl.dwAuthType = AUTHTYPE_SERVER;
    ssl.pwszServerName = const_cast<wchar_t*>(host.c_str());
    CERT_CHAIN_POLICY_PARA policy{};
    policy.cbSize = sizeof(policy);
    policy.pvExtraPolicyPara = &ssl;
    CERT_CHAIN_POLICY_STATUS status{};
    status.cbSize = sizeof(status);
    if (!CertVerifyCertificateChainPolicy(CERT_CHAIN_POLICY_SSL, chain.value, &policy, &status)) winrt::throw_last_error();
    if (status.dwError) throw winrt::hresult_error(winrt::hresult(status.dwError), L"Не прошла проверка сертификата основного API.");
}
}
