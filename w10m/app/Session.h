#pragma once
#include "Protocol.h"
#include "Auth.h"
#include "Certificate.h"
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Networking.h>
#include <winrt/Windows.Storage.Streams.h>
#include <chrono>
#include <atomic>
#include <condition_variable>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <thread>

namespace komet {
class Session : public std::enable_shared_from_this<Session> {
    struct Pending {
        std::condition_variable ready;
        bool done = false;
        Json value;
        std::string error;
        uint16_t opcode = 0;
    };
    winrt::Windows::Networking::Sockets::MessageWebSocket socket_;
    winrt::Windows::Networking::Sockets::StreamSocket native_socket_;
    bool native_ = false;
    std::string device_;
    int64_t seed_ = 0;
    bool has_seed_ = false;
    std::mutex mutex_;
    std::mutex send_mutex_;
    std::map<uint16_t, std::shared_ptr<Pending>> pending_;
    uint32_t seq_ = 0;
    bool closed_ = false;
    winrt::guid broker_task_{};
    std::atomic<bool> handing_off_{false};
    std::mutex read_mutex_;
    std::condition_variable read_done_;
    bool reading_ = false;
    Bytes incoming_;
    std::function<void(Frame)> push_;
    std::function<void()> disconnected_;
    std::function<void(std::string)> error_;

    void Notify(std::string const& reason) {
        if (!error_) return;
        try { error_(reason); } catch (...) {}
    }

    void Fail() {
        std::lock_guard<std::mutex> lock(mutex_);
        closed_ = true;
        for (auto const& entry : pending_) {
            entry.second->error = "Соединение закрыто. Нажмите «Подключиться».";
            entry.second->done = true;
            entry.second->ready.notify_all();
        }
    }
    void Send(Bytes const& bytes) {
        std::lock_guard<std::mutex> lock(send_mutex_);
        winrt::Windows::Storage::Streams::DataWriter writer(native_ ? native_socket_.OutputStream() : socket_.OutputStream());
        try {
            writer.WriteBytes(bytes);
            auto operation = writer.StoreAsync();
            if (operation.wait_for(std::chrono::seconds(30)) == winrt::Windows::Foundation::AsyncStatus::Started) {
                operation.Cancel();
                throw std::runtime_error("Истекло время передачи данных.");
            }
            operation.get();
            writer.DetachStream();
        } catch (std::exception const& error) {
            Notify(std::string("отправка: ") + error.what());
            writer.DetachStream();
            throw;
        } catch (...) {
            Notify("отправка: неизвестная ошибка сокета");
            writer.DetachStream();
            throw;
        }
    }
    void ReceiveBytes(Bytes const& bytes) {
            auto frame = Decode(bytes);
            if (frame.cmd == 0) {
                if (frame.opcode == 1) Send(Encode(1, frame.seq, 1));
                else if (push_) push_(std::move(frame));
                return;
            }
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = pending_.find(frame.seq);
            if (it == pending_.end()) return;
            auto& wait = *it->second;
            if (wait.opcode != frame.opcode) wait.error = "Сервер ответил неверным типом пакета.";
            else if (frame.cmd != 1 || (frame.payload.is_object() && frame.payload.contains("error"))) {
                auto key = Text(frame.payload, "error");
                wait.error = Text(frame.payload, "localizedMessage", Text(frame.payload, "message", key.empty() ? "Ошибка сервера" : key));
                if (!key.empty()) wait.error += " [" + key + "]";
            } else wait.value = std::move(frame.payload);
            wait.done = true;
            wait.ready.notify_one();
    }
    void StartNativeRead() {
        { std::lock_guard<std::mutex> lock(read_mutex_); reading_ = true; }
        auto self = shared_from_this();
        std::thread([self] { winrt::init_apartment(winrt::apartment_type::multi_threaded); self->NativeRead(); }).detach();
    }
    void NativeRead() {
        std::string reason;
        winrt::Windows::Storage::Streams::DataReader reader{nullptr};
        try {
            reader = winrt::Windows::Storage::Streams::DataReader(native_socket_.InputStream());
            reader.InputStreamOptions(winrt::Windows::Storage::Streams::InputStreamOptions::Partial);
            for (;;) {
                for (;;) {
                    auto frame = TakeFrame(incoming_);
                    if (frame.empty()) break;
                    ReceiveBytes(frame);
                }
                if (handing_off_) break;
                auto count = reader.LoadAsync(65536).get();
                if (!count) { reason = "сервер закрыл поток данных"; break; }
                Bytes chunk(count);
                reader.ReadBytes(chunk);
                incoming_.insert(incoming_.end(), chunk.begin(), chunk.end());
                if (incoming_.size() > max_body + 65546) throw std::runtime_error("слишком большой входящий пакет");
            }
        } catch (winrt::hresult_error const& error) {
            reason = "чтение сокета: " + winrt::to_string(error.message());
        } catch (std::exception const& error) { reason = std::string("чтение сокета: ") + error.what(); }
        catch (...) { reason = "чтение сокета: неизвестная ошибка"; }
        if (reader) { try { reader.DetachStream(); } catch (...) {} }
        { std::lock_guard<std::mutex> lock(read_mutex_); reading_ = false; }
        read_done_.notify_all();
        if (handing_off_) return;
        Close();
        if (!reason.empty()) Notify(reason);
        if (disconnected_) disconnected_();
    }
    void Receive(winrt::Windows::Networking::Sockets::MessageWebSocketMessageReceivedEventArgs const& args) {
        try {
            if (args.MessageType() != winrt::Windows::Networking::Sockets::SocketMessageType::Binary)
                throw std::runtime_error("неподдерживаемый тип пакета websocket");
            auto reader = args.GetDataReader();
            auto count = reader.UnconsumedBufferLength();
            if (count > max_body + 10) throw std::runtime_error("слишком большой пакет websocket");
            Bytes bytes(count);
            reader.ReadBytes(bytes);
            ReceiveBytes(bytes);
        } catch (std::exception const& error) {
            Notify(std::string("websocket: ") + error.what());
            Close();
        } catch (...) {
            Notify("websocket: неизвестная ошибка");
            Close();
        }
    }
public:
    ~Session() { Close(); }
    void OnPush(std::function<void(Frame)> callback) { push_ = std::move(callback); }
    void OnDisconnected(std::function<void()> callback) { disconnected_ = std::move(callback); }
    void OnError(std::function<void(std::string)> callback) { error_ = std::move(callback); }
    Json Connect(std::string const& deviceId, bool native = false, bool primary = true, winrt::Windows::Foundation::Uri const& websocket = winrt::Windows::Foundation::Uri(L"wss://api.oneme.ru/websocket")) {
        native_ = native;
        device_ = deviceId;
        if (native_) {
            device_.erase(std::remove(device_.begin(), device_.end(), '-'), device_.end());
            if (device_.size() > 16) device_.resize(16);
            native_socket_.Control().NoDelay(true);
            native_socket_.Control().KeepAlive(true);
            if (broker_task_ != winrt::guid{}) {
                try { native_socket_.EnableTransferOwnership(broker_task_, winrt::Windows::Networking::Sockets::SocketActivityConnectedStandbyAction::Wake); }
                catch (winrt::hresult_error const&) { native_socket_.EnableTransferOwnership(broker_task_); }
            }
            auto host = primary ? L"api2.oneme.ru" : L"api.oneme.ru";
            if (primary) native_socket_.Control().IgnorableServerCertificateErrors().Append(
                winrt::Windows::Security::Cryptography::Certificates::ChainValidationResult::Untrusted);
            auto operation = native_socket_.ConnectAsync(winrt::Windows::Networking::HostName(host), L"443",
                winrt::Windows::Networking::Sockets::SocketProtectionLevel::Tls12);
            if (operation.wait_for(std::chrono::seconds(30)) == winrt::Windows::Foundation::AsyncStatus::Started) {
                operation.Cancel();
                throw std::runtime_error("Сервер не ответил при подключении TLS.");
            }
            try { operation.get(); }
            catch (winrt::hresult_error const& error) { throw winrt::hresult_error(error.code(), L"TLS подключение: " + error.message()); }
            if (primary) ValidateNativeCertificate(native_socket_.Information(), host);
            StartNativeRead();
            auto result = Request(6, NativeHandshake(device_, deviceId, std::chrono::system_clock::now().time_since_epoch().count() & 0x7fffffff));
            has_seed_ = result.contains("callsSeed");
            seed_ = Integer(result, "callsSeed");
            return result;
        }
        auto weak = weak_from_this();
        socket_.Control().MessageType(winrt::Windows::Networking::Sockets::SocketMessageType::Binary);
        socket_.Control().MaxMessageSize(uint32_t(max_body + 10));
        socket_.SetRequestHeader(L"Origin", L"https://web.max.ru");
        socket_.SetRequestHeader(L"User-Agent", L"Mozilla/5.0 (Windows Phone 10.0; ARM; Touch) AppleWebKit/537.36 Edge/15.15254 KometW10M/0.1");
        socket_.MessageReceived([weak](auto const&, auto const& args) {
            if (auto self = weak.lock()) self->Receive(args);
        });
        socket_.Closed([weak](auto const&, auto const&) {
            if (auto self = weak.lock()) {
                self->Fail();
                if (self->disconnected_) self->disconnected_();
            }
        });
        auto operation = socket_.ConnectAsync(websocket);
        if (operation.wait_for(std::chrono::seconds(30)) == winrt::Windows::Foundation::AsyncStatus::Started) {
            operation.Cancel();
            throw std::runtime_error("Сервер недоступен. Проверьте подключение к Интернету.");
        }
        operation.get();
        return Request(6, {{"deviceId", deviceId}, {"userAgent", {
            {"deviceType", "WEB"}, {"pushDeviceType", "WEBPUSH"}, {"locale", "ru"},
            {"deviceLocale", "ru"}, {"osVersion", "Windows 10 Mobile"}, {"deviceName", "Komet UWP"},
            {"headerUserAgent", "Mozilla/5.0 (Windows Phone 10.0; ARM; Touch) Edge/15.15254"},
            {"isPwa", false}, {"appVersion", "26.8.8"}, {"screen", "800x480 1.0x"},
            {"timezone", "Europe/Moscow"}}}});
    }
    Json Request(uint16_t opcode, Json const& payload = nullptr) {
        auto wait = std::make_shared<Pending>();
        wait->opcode = opcode;
        uint16_t seq;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) throw std::runtime_error("Соединение закрыто. Нажмите «Подключиться».");
            if (++seq_ > 32767) throw std::runtime_error("Переподключитесь для обновления сессии.");
            seq = uint16_t(seq_);
            pending_[seq] = wait;
        }
        try { Send(Encode(0, seq, opcode, payload)); }
        catch (...) {
            std::lock_guard<std::mutex> lock(mutex_);
            pending_.erase(seq);
            throw;
        }
        std::unique_lock<std::mutex> lock(mutex_);
        auto done = wait->ready.wait_for(lock, std::chrono::seconds(30), [&] { return wait->done; });
        pending_.erase(seq);
        if (!done) {
            lock.unlock();
            Notify("ответ не получен за 30 с (код запроса " + std::to_string(opcode) + ")");
            throw std::runtime_error(opcode == 64
                ? "Ответ об отправке не получен. Обновите историю перед повторной отправкой."
                : "Сервер не ответил за 30 секунд. Попробуйте подключиться снова.");
        }
        if (!wait->error.empty()) throw std::runtime_error(wait->error);
        return wait->value;
    }
    void Ping(bool interactive = true) {
        uint16_t seq;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) throw std::runtime_error("Соединение закрыто.");
            if (++seq_ > 32767) throw std::runtime_error("Переподключитесь для обновления сессии.");
            seq = uint16_t(seq_);
        }
        Send(Encode(0, seq, 1, {{"interactive", interactive}}));
    }

    Json RequestCode(std::string const& phone, bool resend) {
        if (!native_ || !has_seed_) throw std::runtime_error("Для входа по коду нужна основная сессия Komet с callsSeed. Создайте новое подключение.");
        return Request(17, {{"phone", NormalizePhone(phone)}, {"type", resend ? "RESEND" : "START_AUTH"},
            {"language", "ru"}, {"mode", Json::binary(Fingerprint(seed_, device_))}});
    }
    Json Login(std::string const& token, bool interactive = true) {
        if (native_ && !has_seed_) throw std::runtime_error("Основная сессия не подготовлена для входа.");
        return Request(19, LoginPayload(token, native_, interactive, native_ ? Fingerprint(seed_, device_) : Bytes{}));
    }
    void BrokerTask(winrt::guid const& task) { broker_task_ = task; }
    void Adopt(winrt::Windows::Networking::Sockets::StreamSocket const& socket, Bytes const& context) {
        auto state = context.empty() ? Json::object() : MsgReader(context).Decode();
        native_ = true;
        native_socket_ = socket;
        seq_ = uint32_t(Integer(state, "seq"));
        auto pending = state.find("incoming");
        if (pending != state.end() && pending->is_binary()) incoming_ = pending->get_binary();
        StartNativeRead();
    }
    void Transfer(winrt::hstring const& id) {
        if (!native_ || !native_socket_) throw std::runtime_error("Фоновый сокет недоступен.");
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!pending_.empty()) throw std::runtime_error("Запрос ещё не завершён.");
        }
        handing_off_ = true;
        try {
            native_socket_.CancelIOAsync().get();
            std::unique_lock<std::mutex> lock(read_mutex_);
            if (!read_done_.wait_for(lock, std::chrono::seconds(2), [&] { return !reading_; })) throw std::runtime_error("Не удалось передать сокет в фон.");
            Json state = {{"seq", seq_}, {"incoming", Json::binary(incoming_)}};
            auto bytes = Json::to_msgpack(state);
            winrt::Windows::Storage::Streams::DataWriter writer;
            writer.WriteBytes(bytes);
            native_socket_.TransferOwnership(id, winrt::Windows::Networking::Sockets::SocketActivityContext(writer.DetachBuffer()), std::chrono::seconds(25));
            native_socket_ = nullptr;
            Fail();
        } catch (...) { handing_off_ = false; Close(); throw; }
    }
    bool IsNative() const { return native_; }
    void Close() noexcept {
        Fail();
        try { socket_.Close(1000, L"Closing"); } catch (...) {}
        try { native_socket_.Close(); } catch (...) {}
    }
};
}
